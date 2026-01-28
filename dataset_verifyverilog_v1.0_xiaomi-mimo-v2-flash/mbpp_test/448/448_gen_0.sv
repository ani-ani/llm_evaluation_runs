module PerrinSumCalc (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] COMPUTE  = 2'd1;
    localparam [1:0] DONE     = 2'd2;
    
    reg [1:0] state;
    reg [15:0] a, b, c;        // Perrin sequence registers: a=P(n-3), b=P(n-2), c=P(n-1)
    reg [15:0] sum;            // Running sum
    reg [3:0] counter;         // Iteration counter
    reg [3:0] target_n;        // Store target n value
    reg computation_started;   // Flag to indicate computation has begun

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            a <= 16'd0;
            b <= 16'd0;
            c <= 16'd0;
            sum <= 16'd0;
            counter <= 4'd0;
            target_n <= 4'd0;
            computation_started <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    computation_started <= 1'b0;
                    
                    if (start) begin
                        target_n <= n;
                        counter <= 4'd0;
                        computation_started <= 1'b1;
                        
                        // Handle edge cases for n=0,1,2
                        if (n == 4'd0) begin
                            result <= 16'd3;  // P(0) = 3
                            state <= DONE;
                        end else if (n == 4'd1) begin
                            result <= 16'd3;  // P(0) + P(1) = 3 + 0 = 3
                            state <= DONE;
                        end else if (n == 4'd2) begin
                            result <= 16'd5;  // P(0) + P(1) + P(2) = 3 + 0 + 2 = 5
                            state <= DONE;
                        end else begin
                            // Initialize for n >= 3
                            a <= 16'd3;  // P(0)
                            b <= 16'd0;  // P(1)
                            c <= 16'd2;  // P(2)
                            sum <= 16'd5;  // P(0) + P(1) + P(2)
                            counter <= 4'd3;  // We have computed up to P(2)
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    // Compute next Perrin number: P(n) = P(n-2) + P(n-3)
                    // a = P(n-3), b = P(n-2), c = P(n-1)
                    // Next: a = b, b = c, c = b + a
                    
                    if (counter <= target_n) begin
                        // Compute next value
                        a <= b;
                        b <= c;
                        c <= b + a;  // P(n) = P(n-2) + P(n-3)
                        sum <= sum + (b + a);  // Add to running sum
                        counter <= counter + 4'd1;
                    end
                    
                    // Check if we've reached target
                    if (counter >= target_n) begin
                        result <= sum;
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule