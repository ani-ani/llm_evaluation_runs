module cryptarithm_solver(
    input [3:0] enable,
    output reg [3:0] digit_A,
    output reg [3:0] digit_B,
    output reg [3:0] digit_C,
    output reg valid
);

    // Internal signals for storing the best solution found
    reg [3:0] best_A;
    reg [3:0] best_B;
    reg [3:0] best_C;
    reg found;

    // Combinational logic block
    always @(*) begin
        // Default outputs if disabled or no solution found
        if (!enable) begin
            digit_A = 4'b1111; // High impedance equivalent representation
            digit_B = 4'b1111;
            digit_C = 4'b1111;
            valid = 1'b0;
        end else begin
            // Initialize search state
            best_A = 4'd10; // Max value indicating not found
            best_B = 4'd10;
            best_C = 4'd10;
            found = 1'b0;

            // Nested loops to iterate through combinations
            // Loop for A (Alphabetically lowest, prioritize smallest digit)
            for (integer a = 0; a <= 9; a = a + 1) begin
                // Constraint: A cannot be 0 (Leading letter)
                if (a == 0) continue;

                // Loop for B
                for (integer b = 0; b <= 9; b = b + 1) begin
                    // Constraint: B cannot be 0 (Leading letter)
                    if (b == 0) continue;

                    // Constraint: Distinctness A != B
                    if (a == b) continue;

                    // Loop for C
                    for (integer c = 0; c <= 9; c = c + 1) begin
                        // Constraint: Distinctness C != A and C != B
                        if (c == a || c == b) continue;

                        // Constraint: Arithmetic A + B = C
                        if ((a + b) == c) begin
                            // Found a valid solution
                            // Since we iterate A from 0..9, then B, then C,
                            // the first time we enter this block is the minimal solution.
                            if (!found) begin
                                best_A = a[3:0];
                                best_B = b[3:0];
                                best_C = c[3:0];
                                found = 1'b1;
                            end
                            // We do not break out of the loops explicitly because Verilog 
                            // simulation semantics for 'for' loops in combinational blocks 
                            // execute sequentially. However, to prevent overwriting if logic 
                            // were to run differently, we rely on 'found' flag.
                        end
                    end
                end
            end

            // Assign outputs based on search result
            if (found) begin
                digit_A = best_A;
                digit_B = best_B;
                digit_C = best_C;
                valid = 1'b1;
            end else begin
                // Return 'impossible' (10) if no solution found
                digit_A = 4'd10;
                digit_B = 4'd10;
                digit_C = 4'd10;
                valid = 1'b0;
            end
        end
    end

endmodule}