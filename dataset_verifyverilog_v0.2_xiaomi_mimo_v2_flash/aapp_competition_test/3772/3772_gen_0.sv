module resistance_calculator (
    input clk,
    input rst_n,
    input start,
    input [63:0] a,
    input [63:0] b,
    output reg [63:0] result,
    output reg done
);

    // State definition
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        CALCULATE = 2'b01,
        DONE = 2'b10
    } state_t;

    state_t current_state, next_state;

    // Internal registers for computation
    reg [63:0] current_a;
    reg [63:0] current_b;
    reg [63:0] sum;

    // Divider outputs
    wire [63:0] quotient;
    wire [63:0] remainder;

    // Instantiate 64-bit divider
    // Using div_u from standard Verilog libraries in synthesis context
    // Note: For explicit RTL, a custom divider module or sequential division would be used.
    // Here we assume an available divider IP or behavioral synthesis support.
    // If strict behavioral is required, a combinational divider is used here.
    assign quotient = current_a / current_b;
    assign remainder = current_a % current_b;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = CALCULATE;
                end else begin
                    next_state = IDLE;
                end
            end
            CALCULATE: begin
                if (current_b == 0) begin
                    next_state = DONE;
                end else begin
                    next_state = CALCULATE;
                end
            end
            DONE: begin
                // Stay in DONE until reset or new start (assuming start acts as reset here)
                // To allow re-triggering, we typically go to IDLE or wait for start low.
                // Requirement says wait for start signal in IDLE. 
                // If start is still high, we might stay in DONE, but if start goes low and high again, we need to restart.
                // Let's assume we stay in DONE until reset or start goes low then high.
                // To make it robust, let's go to IDLE when start is low, or stay DONE if start is high.
                // Let's implement: Stay in DONE. The IDLE state checks for start.
                // So if we are DONE, we stay DONE. To restart, user must reset or we need a logic to go back.
                // Typically, 'done' stays high. User de-asserts start. Then asserts start again.
                // Since IDLE checks !start? No, IDLE checks start to go to CALC.
                // If we are in DONE and start is high, we don't leave DONE unless we reset.
                // Usually, we wait for start to go low, then high.
                // Let's transition to IDLE automatically when calculation is done? 
                // Requirement: "DONE: Latch the result and set done high." 
                // It implies it stays there. But to restart, usually we go back to IDLE. 
                // Let's transition to IDLE immediately after one cycle of DONE, or stay there.
                // If we stay in DONE, we need to handle the case where start is held high. 
                // Let's go to IDLE if start is low (ready for next). 
                // Or simpler: stay in DONE until reset.
                // Let's go to IDLE when in DONE and start is low (or simply go to IDLE next cycle).
                // Let's make IDLE wait for start. So if we go to IDLE, we need to ensure we don't loop immediately.
                // Let's stay in DONE until reset.
                next_state = DONE; 
            end
            default: next_state = IDLE;
        endcase
    end

    // Output logic and datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 64'd0;
            done <= 1'b0;
            current_a <= 64'd0;
            current_b <= 64'd0;
            sum <= 64'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_a <= a;
                        current_b <= b;
                        sum <= 64'd0;
                    end
                end

                CALCULATE: begin
                    if (current_b != 0) begin
                        if (current_a < current_b) begin
                            // Swap if a < b (this handles the a < b case in the description)
                            current_a <= current_b;
                            current_b <= current_a;
                            // Note: Since this is sequential logic, assignment order matters. 
                            // We need to capture old values if we want to swap in place in one block, 
                            // but since we are updating both, we can use temp values.
                            // Actually, simply swapping works if we use non-blocking with care.
                            // However, in sequential block, if we do:
                            // current_a <= current_b;
                            // current_b <= current_a;
                            // It swaps. Correct.
                        end else begin
                            // Perform calculation
                            // Add quotient to sum
                            sum <= sum + quotient;
                            // Update current_a = current_b (old value)
                            // Update current_b = remainder
                            // Need to handle the swap case vs standard case.
                            // The problem description says:
                            // "If a > b: add floor(a/b) -> transform to b/(a % b)"
                            // "If a < b: swap"
                            // We can combine this.
                            // If we are here, current_a >= current_b.
                            current_a <= current_b;
                            current_b <= remainder;
                        end
                    end
                end

                DONE: begin
                    result <= sum;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
