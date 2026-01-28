module SnowSensorPlacements (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] snow_levels [0:255],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] CALC = 3'd2;
    localparam [2:0] WAIT_DONE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Modulo constant: 1,000,000,009 (0x3B9ACA09)
    localparam [31:0] MODULO = 32'd1000000009;
    
    // State register
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Counter and control registers
    reg [7:0] i;           // Outer loop index (middle sensor)
    reg [7:0] j;           // Inner loop index (left/right sensors)
    reg [8:0] left_count;  // Count of left elements less than snow_levels[i]
    reg [8:0] right_count; // Count of right elements greater than snow_levels[i]
    reg [31:0] temp_result; // Accumulated result
    reg [31:0] product;     // Product for modulo multiplication
    reg [1:0] calc_step;    // Step counter within CALC state
    reg [7:0] mem_addr;     // Memory address for read
    reg [7:0] snow_val;     // Current snow level value
    
    // Memory for snow levels
    reg [7:0] snow_mem [0:255];
    
    // Initialization and state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            i <= 8'd0;
            j <= 8'd0;
            left_count <= 9'd0;
            right_count <= 9'd0;
            temp_result <= 32'd0;
            product <= 32'd0;
            calc_step <= 2'd0;
            mem_addr <= 8'd0;
            snow_val <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 32'd0;
                    temp_result <= 32'd0;
                    i <= 8'd0;
                    j <= 8'd0;
                    if (start) begin
                        // Copy input to memory (simulated via testbench connection)
                        // Actual memory load is done by external connection
                        // We just proceed to calculation
                        state <= CALC;
                        calc_step <= 2'd0;
                        temp_result <= 32'd0;
                    end
                end
                
                CALC: begin
                    case (calc_step)
                        2'd0: begin
                            // Initialize for current i
                            // Load snow_levels[i]
                            snow_val <= snow_levels[i];
                            left_count <= 9'd0;
                            right_count <= 9'd0;
                            j <= 8'd0;
                            calc_step <= 2'd1;
                        end
                        
                        2'd1: begin
                            // Count left elements (i < j)
                            if (j < i) begin
                                if (snow_levels[j] < snow_val) begin
                                    left_count <= left_count + 9'd1;
                                end
                                j <= j + 8'd1;
                            end else begin
                                // Switch to counting right elements
                                j <= i + 8'd1;
                                calc_step <= 2'd2;
                            end
                        end
                        
                        2'd2: begin
                            // Count right elements (k > i)
                            if (j < 256) begin
                                if (snow_levels[j] > snow_val) begin
                                    right_count <= right_count + 9'd1;
                                end
                                j <= j + 8'd1;
                            end else begin
                                // Calculate contribution: left_count * right_count
                                product <= left_count * right_count;
                                calc_step <= 2'd3;
                            end
                        end
                        
                        2'd3: begin
                            // Add contribution to result with modulo
                            temp_result <= temp_result + product;
                            if (temp_result >= MODULO) begin
                                temp_result <= temp_result - MODULO;
                            end
                            // Move to next i
                            if (i < 255) begin
                                i <= i + 8'd1;
                                calc_step <= 2'd0;
                            end else begin
                                // All i processed
                                calc_step <= 2'd0;
                                state <= WAIT_DONE;
                            end
                        end
                    endcase
                end
                
                WAIT_DONE: begin
                    // Final modulo operation
                    if (temp_result >= MODULO) begin
                        temp_result <= temp_result - MODULO;
                    end else begin
                        result <= temp_result;
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? CALC : IDLE;
            CALC: next_state = CALC; // Stay in CALC until finished
            WAIT_DONE: next_state = (temp_result < MODULO) ? DONE_STATE : WAIT_DONE;
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule