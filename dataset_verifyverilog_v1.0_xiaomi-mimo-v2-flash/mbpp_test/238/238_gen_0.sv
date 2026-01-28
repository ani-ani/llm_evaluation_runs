module calculate_substrings(
    input clk,
    input rst_n,
    input start,
    input [15:0] str_len,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE = 2'd2;
    
    // Internal registers
    reg [1:0] state, next_state;
    reg [31:0] temp_result;
    reg [15:0] str_len_reg;
    
    // Cycle counter for timeout prevention
    reg [6:0] cycle_count;
    localparam [6:0] MAX_CYCLES = 7'd100;
    
    // Combinational multiplication
    wire [31:0] product;
    assign product = str_len_reg * (str_len_reg + 16'd1);
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE;
                else
                    next_state = IDLE;
            end
            COMPUTE: begin
                // Compute in 2 cycles: 1 for multiply, 1 for shift
                if (cycle_count >= 7'd2)
                    next_state = DONE;
                else
                    next_state = COMPUTE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            temp_result <= 32'd0;
            str_len_reg <= 16'd0;
            cycle_count <= 7'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 7'd0;
                    if (start) begin
                        str_len_reg <= str_len;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 7'd1;
                    
                    // First cycle: compute multiplication
                    if (cycle_count == 7'd0) begin
                        temp_result <= product;
                    end
                    // Second cycle: shift right by 1 (divide by 2)
                    else if (cycle_count == 7'd1) begin
                        temp_result <= {1'b0, temp_result[31:1]};
                    end
                    // Extra cycles: stay in compute for stability
                end
                
                DONE: begin
                    result <= temp_result;
                    done <= 1'b1;
                end
                
                default: begin
                    // Should never reach here
                    result <= 32'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule