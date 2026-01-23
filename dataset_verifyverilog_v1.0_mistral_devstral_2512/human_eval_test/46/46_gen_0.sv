module fib4(
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE    = 2'd2;

    // State and next_state registers
    reg [1:0] state, next_state;

    // Iteration counter
    reg [4:0] counter;

    // Fib4 sequence registers
    reg [15:0] f0, f1, f2, f3;
    reg [15:0] new_val;

    // State transition logic (combinational)
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE;
                else
                    next_state = IDLE;
            end

            COMPUTE: begin
                if (counter == n - 5'd4)
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

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            next_state <= IDLE;
            counter <= 5'd0;
            f0 <= 16'd0;
            f1 <= 16'd0;
            f2 <= 16'd2;
            f3 <= 16'd0;
            new_val <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            // State update
            state <= next_state;

            // State actions
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 5'd0;
                    // Initialize base cases
                    f0 <= 16'd0;
                    f1 <= 16'd0;
                    f2 <= 16'd2;
                    f3 <= 16'd0;
                end

                COMPUTE: begin
                    // Handle base cases (n <= 3)
                    if (n <= 5'd3) begin
                        case (n)
                            5'd0: result <= 16'd0;
                            5'd1: result <= 16'd0;
                            5'd2: result <= 16'd2;
                            5'd3: result <= 16'd0;
                            default: result <= 16'd0;
                        endcase
                        counter <= n - 5'd4; // Force completion
                    end else begin
                        // Iterative calculation
                        if (counter == 5'd0) begin
                            // First iteration uses base values
                            new_val <= f3 + f2 + f1 + f0;
                        end else begin
                            // Subsequent iterations
                            new_val <= f3 + f2 + f1 + f0;
                        end
                        
                        // Shift register values
                        f0 <= f1;
                        f1 <= f2;
                        f2 <= f3;
                        f3 <= new_val;
                        
                        // Update result with current value
                        result <= new_val;
                        
                        // Increment counter
                        counter <= counter + 5'd1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    // Final result is already computed in COMPUTE state
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule