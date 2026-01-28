module divisor_counter(
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    output reg result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COUNTING = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [15:0] i;
    reg [7:0] count;
    reg [15:0] sqrt_n;
    reg [15:0] remainder;
    reg [15:0] quotient;
    
    // Compute square root (floor)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sqrt_n <= 16'd0;
        end else if (state == IDLE && start) begin
            // Binary search for sqrt
            reg [15:0] low = 16'd0;
            reg [15:0] high = 16'd256;
            reg [15:0] mid;
            reg [15:0] mid_sq;
            integer j;
            
            for (j = 0; j < 16; j = j + 1) begin
                mid = (low + high) >> 1;
                mid_sq = mid * mid;
                if (mid_sq <= n) begin
                    low = mid + 16'd1;
                end else begin
                    high = mid;
                end
            end
            sqrt_n <= low - 16'd1;
        end
    end
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 16'd0;
            count <= 8'd0;
            result <= 1'b0;
            done <= 1'b0;
            remainder <= 16'd0;
            quotient <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COUNTING;
                        i <= 16'd1;
                        count <= 8'd0;
                    end
                end
                
                COUNTING: begin
                    // Check if i is a divisor
                    remainder = n % i;
                    quotient = n / i;
                    
                    if (remainder == 16'd0) begin
                        if (quotient == i) begin
                            // Perfect square
                            count <= count + 8'd1;
                        end else begin
                            // Two divisors
                            count <= count + 8'd2;
                        end
                    end
                    
                    // Move to next i
                    if (i < sqrt_n) begin
                        i <= i + 16'd1;
                    end else begin
                        state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    // Determine if count is even
                    result <= (count % 2 == 0);
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule