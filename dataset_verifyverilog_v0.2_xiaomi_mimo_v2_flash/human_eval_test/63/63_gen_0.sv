module fibfib (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    output reg [15:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam INIT = 2'b01;
    localparam COMPUTE = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state;
    reg [4:0] i;
    reg [15:0] fib_prev3, fib_prev2, fib_prev1;
    reg [4:0] n_reg;

    // Next State Logic & Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Base cases handling
                    if (n_reg == 5'd0) begin
                        result <= 16'd0;
                        state <= DONE;
                    end else if (n_reg == 5'd1) begin
                        result <= 16'd0;
                        state <= DONE;
                    end else if (n_reg == 5'd2) begin
                        result <= 16'd1;
                        state <= DONE;
                    end else begin
                        // Initialize for computation (n >= 3)
                        // Sequence: 0, 0, 1, ...
                        // i represents the index we are about to compute
                        // At start of compute loop for n=3, we need to compute index 3
                        fib_prev3 <= 16'd0; // fibfib(0)
                        fib_prev2 <= 16'd0; // fibfib(1)
                        fib_prev1 <= 16'd1; // fibfib(2)
                        i <= 5'd3;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // fibfib(i) = fibfib(i-1) + fibfib(i-2) + fibfib(i-3)
                    result <= fib_prev1 + fib_prev2 + fib_prev3;
                    
                    // Shift registers for next iteration
                    fib_prev3 <= fib_prev2;
                    fib_prev2 <= fib_prev1;
                    fib_prev1 <= fib_prev1 + fib_prev2 + fib_prev3;
                    
                    i <= i + 1;

                    // Check if we have reached n
                    if (i == n_reg) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    // Stay here until reset or start goes low (implied by IDLE transition)
                    // In this design, we rely on start going low to transition back to IDLE is not explicit,
                    // but usually done holds until reset or a new start sequence.
                    // To be safe and follow standard FSM, we wait for start to drop or reset.
                    // However, typical behavior: hold result. 
                    // Let's transition back to IDLE only when start is low to allow re-triggering.
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Output logic for done (combinational or registered)
    // The specification says "Result valid when done signal is high"
    // Since we registered done, we need to ensure it is set in DONE state.
    // The always block above sets done to 0 on reset and handles DONE state.
    // Wait, the always block sets done to 0 on reset. 
    // In DONE state, we need to assert done. The code above updates done in the IDLE block.
    // Let's fix the output logic for done to be safe.
    
    // Re-structuring the always block to ensure 'done' is correctly asserted in DONE state
    // and de-asserted properly.
    
endmodule

// Correction: The previous block was slightly messy regarding the 'done' signal updates.
// Let's rewrite the module cleanly ensuring all requirements are met.

module fibfib_corrected (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    output reg [15:0] result,
    output reg done
);

    localparam IDLE = 2'b00;
    localparam INIT = 2'b01;
    localparam COMPUTE = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state;
    reg [4:0] i;
    reg [15:0] fib_prev3, fib_prev2, fib_prev1;
    reg [4:0] n_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'b0;
        end else begin
            // Default assignments
            done <= 1'b0; // Done is pulsed or held based on state, but typically needs to be 0 unless in DONE
            
            case (state)
                IDLE: begin
                    if (start) begin
                        n_reg <= n;
                        state <= INIT;
                    end
                end

                INIT: begin
                    if (n_reg < 5'd3) begin
                        case (n_reg)
                            0, 1: result <= 16'd0;
                            2: result <= 16'd1;
                        endcase
                        state <= DONE;
                    end else begin
                        // Setup for Compute
                        fib_prev3 <= 16'd0;
                        fib_prev2 <= 16'd0;
                        fib_prev1 <= 16'd1;
                        i <= 5'd3;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // Calculate next value
                    // fibfib(i) = fib_prev1 + fib_prev2 + fib_prev3
                    result <= fib_prev1 + fib_prev2 + fib_prev3;
                    
                    // Update shift registers for next cycle
                    // New prev3 = old prev2
                    // New prev2 = old prev1
                    // New prev1 = fibfib(i) (which is result of this cycle)
                    fib_prev3 <= fib_prev2;
                    fib_prev2 <= fib_prev1;
                    fib_prev1 <= fib_prev1 + fib_prev2 + fib_prev3;
                    
                    i <= i + 1;

                    // Check termination condition
                    if (i == n_reg) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    // Hold result
                    // Transition back to IDLE when start is released (low)
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
