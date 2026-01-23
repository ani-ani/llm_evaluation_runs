module lights_max (
    input clk,
    input rst_n,
    input start,
    input [7:0] initial_state,  // 8-bit initial state for lights
    input [2:0] a [0:7],        // periods for 8 lights (1-5)
    input [2:0] b [0:7],        // offsets for 8 lights (1-5)
    output reg [7:0] max_count  // maximum number of lights on simultaneously
);

// State definitions
localparam [1:0] IDLE = 2'd0;
localparam [1:0] SIMULATE = 2'd1;
localparam [1:0] UPDATE_MAX = 2'd2;
localparam [1:0] NEXT_TIME = 2'd3;

// Registers
reg [1:0] state;
reg [6:0] time_counter;     // 0-120 seconds
reg [2:0] light_counter;    // 0-7 lights
reg [7:0] current_states;   // current state of all lights
reg [7:0] max_count_reg;    // internal max counter
reg [7:0] current_count;    // count of current on lights

// Combinational logic for toggle detection
wire should_toggle;
wire [2:0] period;
wire [2:0] offset;
wire light_on;

assign period = a[light_counter];
assign offset = b[light_counter];
assign light_on = current_states[light_counter];

// Check if this light should toggle at current time
assign should_toggle = (time_counter >= offset) && 
                      ((time_counter - offset) % period == 0);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        time_counter <= 7'd0;
        light_counter <= 3'd0;
        current_states <= 8'd0;
        max_count_reg <= 8'd0;
        current_count <= 8'd0;
        max_count <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    current_states <= initial_state;
                    time_counter <= 7'd0;
                    light_counter <= 3'd0;
                    max_count_reg <= 8'd0;
                    current_count <= 8'd0;
                    state <= SIMULATE;
                end
            end
            
            SIMULATE: begin
                // Check if this light should toggle
                if (should_toggle) begin
                    current_states[light_counter] <= ~light_on;
                    // Update current count if state changes
                    if (light_on) begin
                        current_count <= current_count - 8'd1;
                    end else begin
                        current_count <= current_count + 8'd1;
                    end
                end
                
                if (light_counter == 3'd7) begin
                    light_counter <= 3'd0;
                    state <= UPDATE_MAX;
                end else begin
                    light_counter <= light_counter + 3'd1;
                end
            end
            
            UPDATE_MAX: begin
                if (current_count > max_count_reg) begin
                    max_count_reg <= current_count;
                end
                state <= NEXT_TIME;
            end
            
            NEXT_TIME: begin
                if (time_counter == 7'd120) begin
                    max_count <= max_count_reg;
                    state <= IDLE;
                end else begin
                    time_counter <= time_counter + 7'd1;
                    light_counter <= 3'd0;
                    // Reset current_count for new time step
                    current_count <= 8'd0;
                    // Recalculate current_count from current_states
                    current_count <= current_states[0] + current_states[1] + 
                                   current_states[2] + current_states[3] + 
                                   current_states[4] + current_states[5] + 
                                   current_states[6] + current_states[7];
                    state <= SIMULATE;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule