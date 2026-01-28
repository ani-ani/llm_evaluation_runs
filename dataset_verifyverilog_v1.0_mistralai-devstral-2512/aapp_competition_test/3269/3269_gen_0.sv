module digit_distance_sum(
    input clk,
    input rst_n,
    input start,
    input [3:0] A,
    input [3:0] B,
    input [3:0] len,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CONVERT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Internal registers
    reg [13:0] A_int, B_int;  // 0-9999 fits in 14 bits
    reg [13:0] i_reg, j_reg;
    reg [31:0] sum_reg;
    reg [3:0] i_digits [0:3], j_digits [0:3];
    reg [3:0] i_digit_temp, j_digit_temp;
    reg [7:0] distance;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Convert 4-digit BCD to integer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            A_int <= 14'd0;
            B_int <= 14'd0;
            i_reg <= 14'd0;
            j_reg <= 14'd0;
            sum_reg <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CONVERT;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                CONVERT: begin
                    // Convert A and B from BCD to integers
                    A_int <= A[3] * 1000 + A[2] * 100 + A[1] * 10 + A[0];
                    B_int <= B[3] * 1000 + B[2] * 100 + B[1] * 10 + B[0];
                    next_state <= COMPUTE;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Initialize i and j for first iteration
                    if (i_reg == 14'd0) begin
                        i_reg <= A_int;
                        j_reg <= A_int + 14'd1;
                    end
                    
                    // Extract digits of i and j
                    i_digits[0] <= i_reg[3:0];
                    i_digits[1] <= i_reg[7:4];
                    i_digits[2] <= i_reg[11:8];
                    i_digits[3] <= i_reg[13:12];
                    
                    j_digits[0] <= j_reg[3:0];
                    j_digits[1] <= j_reg[7:4];
                    j_digits[2] <= j_reg[11:8];
                    j_digits[3] <= j_reg[13:12];
                    
                    // Compute digit distance
                    distance <= (i_digits[3] > j_digits[3] ? i_digits[3] - j_digits[3] : j_digits[3] - i_digits[3]) +
                               (i_digits[2] > j_digits[2] ? i_digits[2] - j_digits[2] : j_digits[2] - i_digits[2]) +
                               (i_digits[1] > j_digits[1] ? i_digits[1] - j_digits[1] : j_digits[1] - i_digits[1]) +
                               (i_digits[0] > j_digits[0] ? i_digits[0] - j_digits[0] : j_digits[0] - i_digits[0]);
                    
                    // Accumulate sum modulo 1000000007
                    sum_reg <= sum_reg + distance;
                    if (sum_reg >= 32'd1000000007) begin
                        sum_reg <= sum_reg - 32'd1000000007;
                    end
                    
                    // Move to next pair
                    if (j_reg == B_int) begin
                        i_reg <= i_reg + 14'd1;
                        j_reg <= i_reg + 14'd1;
                    end else begin
                        j_reg <= j_reg + 14'd1;
                    end
                    
                    // Check if all pairs processed
                    if (i_reg == B_int - 14'd1 && j_reg == B_int) begin
                        next_state <= FINISH;
                    end else begin
                        next_state <= COMPUTE;
                    end
                end
                
                FINISH: begin
                    result <= sum_reg;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule