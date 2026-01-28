module digit_sum(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] num_in,
    output reg [7:0] sum_out,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    // Internal registers
    reg [1:0] state, next_state;
    reg [15:0] num_reg;
    reg [7:0] sum_reg;
    reg [7:0] digit;
    reg [15:0] quotient;
    reg [15:0] remainder;
    
    // Division by 10 lookup table (non-restoring)
    wire [15:0] div10_quotient;
    wire [3:0] div10_remainder;
    
    assign div10_quotient = num_reg[15:4] - (num_reg[15:4] >= 16'd6554 ? 16'd655 : 16'd0);
    assign div10_remainder = num_reg[3:0] + (num_reg[15:4] >= 16'd6554 ? 4'd10 : 4'd0);
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESSING;
                else
                    next_state = IDLE;
            end
            
            PROCESSING: begin
                if (num_reg == 16'd0)
                    next_state = COMPLETE;
                else
                    next_state = PROCESSING;
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // State register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sum_reg <= 8'd0;
            num_reg <= 16'd0;
            digit <= 8'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        num_reg <= num_in;
                        sum_reg <= 8'd0;
                    end
                end
                
                PROCESSING: begin
                    // Extract last digit (num % 10)
                    digit <= div10_remainder;
                    
                    // Add to accumulator
                    sum_reg <= sum_reg + digit;
                    
                    // Update number (num / 10)
                    num_reg <= div10_quotient;
                    
                    done <= 1'b0;
                end
                
                COMPLETE: begin
                    sum_out <= sum_reg;
                    done <= 1'b1;
                end
                
                default: begin
                    sum_out <= 8'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule