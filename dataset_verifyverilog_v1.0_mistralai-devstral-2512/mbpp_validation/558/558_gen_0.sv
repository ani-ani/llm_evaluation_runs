module digit_diff_sum(
    input clk,
    input rst_n,
    input start,
    input signed [15:0] a,
    input signed [15:0] b,
    output reg [7:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Intermediate signals
    reg [15:0] diff;
    reg [15:0] temp_diff;
    reg [7:0] digit_sum;
    reg [3:0] digit_index;
    reg [15:0] current_digit;
    
    // Division by 10 hardware
    wire [15:0] div10_quotient;
    wire [15:0] div10_remainder;
    
    assign div10_quotient = temp_diff / 16'd10;
    assign div10_remainder = temp_diff % 16'd10;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            diff <= 16'd0;
            temp_diff <= 16'd0;
            digit_sum <= 8'd0;
            digit_index <= 4'd0;
            current_digit <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Compute absolute difference
                        if (a > b) begin
                            diff <= a - b;
                        end else begin
                            diff <= b - a;
                        end
                        temp_diff <= diff;
                        digit_sum <= 8'd0;
                        digit_index <= 4'd0;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Extract current digit (LSB)
                    current_digit <= div10_remainder;
                    digit_sum <= digit_sum + current_digit[7:0];
                    
                    // Move to next digit
                    temp_diff <= div10_quotient;
                    digit_index <= digit_index + 4'd1;
                    
                    // Check if all digits processed or max cycles reached
                    if (digit_index == 4'd5 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Clamp result to 8 bits
                    if (digit_sum > 8'd255) begin
                        result <= 8'd255;
                    end else begin
                        result <= digit_sum[7:0];
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule