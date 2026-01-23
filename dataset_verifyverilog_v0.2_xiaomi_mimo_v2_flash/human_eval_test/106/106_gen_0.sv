module factorial_sum_sequence (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    output reg [31:0] result,
    output reg [2:0] index,
    output reg valid,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam SETUP = 3'b001;
    localparam CALCULATE = 3'b010;
    localparam OUTPUT = 3'b011;
    localparam COMPLETE = 3'b100;

    // Internal Registers
    reg [2:0] current_state, next_state;
    reg [2:0] current_index;
    reg [31:0] accumulator;
    reg [31:0] multiplier;
    reg [2:0] loop_counter;
    reg calculation_done;

    // State Register and Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            current_index <= 3'b0;
            index <= 3'b0;
            result <= 32'b0;
            valid <= 1'b0;
            done <= 1'b0;
            accumulator <= 32'b0;
            multiplier <= 32'b0;
            loop_counter <= 3'b0;
            calculation_done <= 1'b0;
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    if (start) begin
                        current_index <= 3'b0;
                        done <= 1'b0;
                    end
                end

                SETUP: begin
                    // Initialize calculation based on current_index
                    // Sequence logic: (i+1). index is 0-indexed.
                    // If (index+1) is even (index is odd): Factorial
                    // If (index+1) is odd (index is even): Sum
                    // Fixed mapping based on example:
                    // idx 0 -> val 1 (1!) -> Factorial (1 is odd, but 1! is 1)
                    // Wait, example says:
                    // idx 0 -> 1 (1!) -> Factorial
                    // idx 1 -> 2 (1..2 sum) -> Sum
                    // idx 2 -> 6 (3!) -> Factorial
                    // Pattern: index 0 (even) -> Factorial, index 1 (odd) -> Sum, index 2 (even) -> Factorial
                    // Correct Pattern: Index is even (0, 2, 4...) -> Factorial. Index is odd (1, 3, 5...) -> Sum.
                    
                    if (current_index[0] == 1'b0) begin // Even index -> Factorial
                        accumulator <= 32'd1; // 0! * 1 = 1 (start multiply base)
                        multiplier <= {29'b0, current_index + 1}; // (index + 1)
                        loop_counter <= 3'd0; // We need to multiply (index+1) times, but logic usually iterates 0 to (n-1)
                        // Logic: result = 1; for i=1 to (index+1) result *= i
                        // If index+1 is 1 (index 0), we need 0 iterations? No, 1! = 1*1. 
                        // Let's say we need (index+1) iterations of multiplication.
                        // Iter 0: *1, Iter 1: *2... 
                        // If index=0 (1!), need to multiply 1 once? 1! = 1. 
                        // Let's set loop counter to (index + 1).
                        loop_counter <= current_index + 1; 
                    end else begin // Odd index -> Sum
                        accumulator <= 32'd0; // Sum starts at 0
                        // We need to sum numbers 1 to (index+1)
                        multiplier <= 32'd1; // Start adding from 1
                        loop_counter <= current_index + 1; // Number of adds needed
                    end
                end

                CALCULATE: begin
                    if (loop_counter != 0) begin
                        if (current_index[0] == 1'b0) begin // Factorial
                            accumulator <= accumulator * multiplier;
                            multiplier <= multiplier - 1;
                            loop_counter <= loop_counter - 1;
                        end else begin // Sum
                            accumulator <= accumulator + multiplier;
                            multiplier <= multiplier + 1;
                            loop_counter <= loop_counter - 1;
                        end
                    end else begin
                        calculation_done <= 1'b1;
                    end
                end

                OUTPUT: begin
                    // Transfer result to outputs
                    result <= accumulator;
                    index <= current_index;
                    valid <= 1'b1;
                    calculation_done <= 1'b0;
                    
                    // Increment index for next cycle
                    current_index <= current_index + 1;
                end

                COMPLETE: begin
                    valid <= 1'b0;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = SETUP;
                else next_state = IDLE;
            end

            SETUP: begin
                // Check if we have processed enough elements
                if (n == 3'b0 || current_index >= n) begin
                    next_state = COMPLETE;
                end else begin
                    next_state = CALCULATE;
                end
            end

            CALCULATE: begin
                // Continue looping until calculation is done (loop_counter hits 0)
                // If calculation_done is set by sequential logic, we check it here or stay in CALCULATE
                // Optimization: check loop_counter from previous cycle or current?
                // The logic above updates loop_counter in CALCULATE.
                // We need to wait for the result of the last operation.
                // If loop_counter becomes 0 in this state's logic (prev cycle update), calculation is done.
                // The sequential logic updates accumulator. We check the loop_counter value at the end of cycle.
                if (loop_counter == 0) next_state = OUTPUT;
                else next_state = CALCULATE;
            end

            OUTPUT: begin
                // Go back to SETUP to prepare next value, or COMPLETE if done
                next_state = SETUP;
            end

            COMPLETE: begin
                if (!start) next_state = IDLE; // Wait for start to go low before accepting new start
                else next_state = COMPLETE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule