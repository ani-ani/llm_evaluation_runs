module StringTransformCost(
    input clk,
    input rst_n,
    input start,
    input [7:0] s1_char,
    input [7:0] s2_char,
    input char_valid,
    input string_end,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] CALCULATING = 2'd1;
    localparam [1:0] FINISH     = 2'd2;
    
    reg [1:0] state, next_state;
    reg [31:0] accumulator;
    reg [7:0] abs_diff;
    reg [15:0] cycle_count;  // Safety counter for simulation
    localparam [15:0] MAX_CYCLES = 16'd20000;  // Safety limit
    
    // Combinational logic for absolute difference
    always @(*) begin
        if (s1_char > s2_char)
            abs_diff = s1_char - s2_char;
        else
            abs_diff = s2_char - s1_char;
    end
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            accumulator <= 32'd0;
            cycle_count <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    accumulator <= 32'd0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        // Transition handled by next_state logic
                    end
                end
                
                CALCULATING: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    if (char_valid) begin
                        accumulator <= accumulator + {24'd0, abs_diff};
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= accumulator;
                    accumulator <= 32'd0;  // Clear for next operation
                end
                
                default: begin
                    state <= IDLE;
                    result <= 32'd0;
                    done <= 1'b0;
                    accumulator <= 32'd0;
                    cycle_count <= 16'd0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CALCULATING;
                else
                    next_state = IDLE;
            end
            
            CALCULATING: begin
                // Exit conditions: string_end or safety timeout
                if (string_end || (cycle_count >= MAX_CYCLES))
                    next_state = FINISH;
                else
                    next_state = CALCULATING;
            end
            
            FINISH: begin
                // One cycle pulse, return to idle
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
endmodule