module lights_sim (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [99:0] init_state,
    input wire [299:0] a,
    input wire [299:0] b,
    output reg [7:0] max_on,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] SIMULATE = 2'd1;
    localparam [1:0] UPDATE   = 2'd2;
    localparam [1:0] FINISH   = 2'd3;

    // Simulation registers
    reg [1:0] state;
    reg [7:0] time_counter;        // t from 0 to 255
    reg [7:0] max_on_reg;          // Internal max register
    reg [6:0] light_idx;           // Light index 0-99
    reg [6:0] on_count;            // Count of lights ON at current time
    reg [7:0] cycle_count;         // Safety counter for timeout
    localparam [7:0] MAX_CYCLES = 8'd250;

    // Latched inputs
    reg [99:0] latched_init_state;
    reg [299:0] latched_a;
    reg [299:0] latched_b;

    // Temp variables for calculation
    reg light_on;
    reg [7:0] toggle_count;
    reg [7:0] diff;

    // Combinational logic for single light state calculation
    // We need to index into a and b arrays. Since a/b are packed [99:0][2:0]
    // Index i means bits [i*3+2 : i*3]
    wire [2:0] current_a;
    wire [2:0] current_b;
    wire current_init;
    
    assign current_a = latched_a[light_idx*3 +: 3];
    assign current_b = latched_b[light_idx*3 +: 3];
    assign current_init = latched_init_state[light_idx];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_on <= 8'd0;
            done <= 1'b0;
            max_on_reg <= 8'd0;
            time_counter <= 8'd0;
            light_idx <= 7'd0;
            on_count <= 7'd0;
            cycle_count <= 8'd0;
            latched_init_state <= 100'd0;
            latched_a <= 300'd0;
            latched_b <= 300'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    max_on_reg <= 8'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Latch inputs
                        latched_init_state <= init_state;
                        latched_a <= a;
                        latched_b <= b;
                        // Reset simulation state
                        time_counter <= 8'd0;
                        light_idx <= 7'd0;
                        on_count <= 7'd0;
                        state <= SIMULATE;
                    end
                end

                SIMULATE: begin
                    // At start of each time step, reset counters
                    on_count <= 7'd0;
                    light_idx <= 7'd0;
                    state <= UPDATE;
                end

                UPDATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate state for current light (light_idx) at current time (time_counter)
                    light_on <= 1'b0; // Default
                    
                    if (time_counter < current_b) begin
                        // t < b: state = init_state
                        light_on <= current_init;
                    end else begin
                        // t >= b: toggle count = ((t - b) / a) + 1
                        // Integer division in Verilog is truncating
                        // We need to calculate: ((time_counter - current_b) / current_a) + 1
                        // Note: current_a is 3-bit (1-5), non-zero
                        diff = time_counter - current_b;
                        toggle_count = (diff / current_a) + 1;
                        
                        // If toggle count is even: state = init_state
                        // If toggle count is odd: state = NOT init_state
                        if (toggle_count[0] == 1'b0) begin // Even
                            light_on <= current_init;
                        end else begin // Odd
                            light_on <= ~current_init;
                        end
                    end

                    // Accumulate count (registered update happens next cycle effectively for sequential logic)
                    // However, for combinational accumulation, we need to handle it carefully.
                    // Since this is a sequential block, we are calculating 'light_on' for current light.
                    // We need to add this to 'on_count'.
                    // To do this without a combinational loop, we add in the next cycle or use a temp variable.
                    // Let's add to on_count now.
                    on_count <= on_count + light_on;

                    // Advance index
                    if (light_idx < 7'd99) begin
                        light_idx <= light_idx + 7'd1;
                    end else begin
                        // Finished counting for this time step
                        // Check max
                        if (on_count > max_on_reg) begin
                            max_on_reg <= on_count;
                        end
                        
                        // Advance time
                        if (time_counter < 8'd255) begin
                            time_counter <= time_counter + 8'd1;
                            state <= SIMULATE;
                        end else begin
                            // Simulation complete
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    max_on <= max_on_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule