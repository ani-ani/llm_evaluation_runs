module fib_iterative (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [4:0] counter;           // Iteration counter
    reg [15:0] fib_prev;         // fib(k-1)
    reg [15:0] fib_curr;         // fib(k)
    reg [4:0] target_n;          // Store n during computation
    reg done_internal;           // Internal done signal

    // State transition logic (combinational)
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = IDLE;
                end
            end
            COMPUTE: begin
                // Compute until counter reaches target_n
                if (counter >= target_n) begin
                    next_state = FINISH;
                end else begin
                    next_state = COMPUTE;
                end
            end
            FINISH: begin
                // Return to IDLE after one cycle
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            counter <= 5'd0;
            fib_prev <= 16'd0;
            fib_curr <= 16'd0;
            target_n <= 5'd0;
            done_internal <= 1'b0;
        end else begin
            // Next state
            state <= next_state;
            done <= 1'b0;  // Clear done by default

            case (state)
                IDLE: begin
                    if (start) begin
                        // Initialize for computation
                        target_n <= n;
                        counter <= 5'd0;
                        done_internal <= 1'b0;
                        
                        // Handle edge cases immediately
                        if (n == 5'd0) begin
                            fib_prev <= 16'd0;
                            fib_curr <= 16'd0;
                            counter <= 5'd0;
                        end else if (n == 5'd1) begin
                            fib_prev <= 16'd0;
                            fib_curr <= 16'd1;
                            counter <= 5'd1;
                        end else begin
                            // n >= 2: initialize for iterative computation
                            fib_prev <= 16'd0;  // fib(0)
                            fib_curr <= 16'd1;  // fib(1)
                            counter <= 5'd1;    // We have fib(1) already
                        end
                    end
                end

                COMPUTE: begin
                    // Iterate until counter >= target_n
                    if (counter < target_n) begin
                        // Compute fib(counter + 1) = fib(counter) + fib(counter-1)
                        fib_prev <= fib_curr;
                        fib_curr <= fib_prev + fib_curr;
                        counter <= counter + 5'd1;
                    end else if (counter == target_n) begin
                        // Target reached, result is in fib_curr
                        result <= fib_curr;
                        done_internal <= 1'b1;
                    end
                end

                FINISH: begin
                    // Generate done pulse and return to IDLE
                    done <= 1'b1;
                    done_internal <= 1'b0;
                end

                default: begin
                    state <= IDLE;
                    result <= 16'd0;
                    done <= 1'b0;
                    counter <= 5'd0;
                    fib_prev <= 16'd0;
                    fib_curr <= 16'd0;
                    target_n <= 5'd0;
                    done_internal <= 1'b0;
                end
            endcase
        end
    end

endmodule