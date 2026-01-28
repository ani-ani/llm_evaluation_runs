module FibonacciIterative(
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [15:0] fib_prev;  // fib(k-2)
    reg [15:0] fib_curr;  // fib(k-1)
    reg [15:0] fib_next;  // fib(k)
    reg [3:0] counter;    // Iteration counter
    reg [3:0] max_count;  // Maximum iterations (n)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            fib_prev <= 16'd0;
            fib_curr <= 16'd0;
            fib_next <= 16'd0;
            counter <= 4'd0;
            max_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        max_count <= n;
                        fib_prev <= 16'd0;  // fib(0)
                        fib_curr <= 16'd1;  // fib(1)
                        counter <= 4'd0;
                    end
                end
                
                COMPUTE: begin
                    // Edge cases: n=0 or n=1
                    if (max_count == 4'd0) begin
                        result <= 16'd0;
                        state <= FINISH;
                    end else if (max_count == 4'd1) begin
                        result <= 16'd1;
                        state <= FINISH;
                    end else begin
                        // Iterative computation
                        if (counter < max_count - 4'd1) begin
                            fib_next <= fib_prev + fib_curr;
                            fib_prev <= fib_curr;
                            fib_curr <= fib_next;
                            counter <= counter + 4'd1;
                        end else begin
                            result <= fib_next;
                            state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule