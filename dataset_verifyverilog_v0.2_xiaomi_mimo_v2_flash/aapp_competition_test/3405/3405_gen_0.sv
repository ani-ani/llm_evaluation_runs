module digit_rotate_multiplier (
    input clk,
    input rst_n,
    input start,
    input [31:0] x_fixed,
    output reg [31:0] result,
    output reg valid,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam CHECK = 3'b001;
    localparam ROTATE = 3'b010;
    localparam VERIFY = 3'b011;
    localparam NEXT = 3'b100;
    localparam DONE = 3'b101;

    // Registers
    reg [2:0] state;
    reg [31:0] n_current;
    reg [31:0] n_next;
    reg [31:0] product;
    reg [31:0] rotated;
    reg [31:0] x_fixed_reg;
    reg found_match;

    // Wires for calculations
    wire [63:0] mult_result;
    wire [31:0] product_fixed;

    // Multiplication logic: (n * x_fixed) >> 16
    // Input n_current is treated as integer (0-9999)
    // x_fixed is Q16.16
    // Result should be Q16.16, we want the integer part of the product
    // Since we compare with an integer (rotated), we take product_fixed = (n_current * x_fixed) >> 16
    // n_current needs to be promoted to 32-bit for multiplication logic if we want full precision,
    // but since n_current is small, 32x32 multiplication is safe.
    // Actually, if n_current is an integer (e.g., 135), and we multiply by Q16.16 (e.g., 2.6 * 65536),
    // the result is 135 * 2.6 = 351.
    // 135 * 170393 (2.6 * 65536) = 22,999,055.
    // Right shift by 16 gives 350.99... -> 350 (truncated).
    // Note: We need to align n_current. It is an integer. We can treat it as Q0.0.
    // So n_current << 16 * x_fixed >> 16 is wrong.
    // Correct: (n_current * x_fixed) >> 16.
    // n_current is 16 bits max. x_fixed is 32 bits.
    // Let's cast n_current to [31:0] for multiplication.
    // (n_current * x_fixed) is effectively (0.0.16 * 16.16) -> 16.32. Shift right 16 -> 16.16.
    // We want to compare the integer part.
    assign mult_result = {16'b0, n_current[15:0]} * x_fixed_reg;
    assign product_fixed = mult_result[47:16]; // Shift right 16, take top 32 bits of result (bits 63:0)
    // Result range: if n=9999, x=10, res = 99990. Fits in 17 bits. Safe.

    // Rotation Logic: 
    // Need to handle 3 and 4 digit numbers.
    // Extract digits. 
    // If 4 digits: d3 d2 d1 d0. New = d2 d1 d0 d3.
    // If 3 digits: d2 d1 d0. New = d1 d0 d2.
    // We can detect leading zero or range.
    wire [3:0] d3, d2, d1, d0;
    assign d3 = n_current / 1000;
    assign d2 = (n_current % 1000) / 100;
    assign d1 = (n_current % 100) / 10;
    assign d0 = n_current % 10;

    // Determine if 3 or 4 digits (100-9999)
    // If d3 != 0, it's 4 digits.
    // If d3 == 0, check d2. If d2 != 0, it's 3 digits.
    wire is_4_digits;
    assign is_4_digits = (d3 != 0);

    // Rotated value calculation (combinational for CHECK/ROTATE states)
    // We calculate the candidate rotated value based on digit count
    always @(*) begin
        if (is_4_digits) begin
            // d2 d1 d0 d3
            rotated = d2 * 1000 + d1 * 100 + d0 * 10 + d3;
        end else begin
            // 3 digits (or less, but range ensures >= 100)
            // d1 d0 d2
            rotated = d2 * 100 + d1 * 10 + d0; // Wait, d2 is hundreds, d1 tens, d0 ones.
            // Correct rotation for 3 digits: 123 -> 231.
            // 123: d2=1, d1=2, d0=3. 
            // 231: 2*100 + 3*10 + 1.
            // Formula: d1*100 + d0*10 + d2.
            rotated = d1 * 100 + d0 * 10 + d2;
        end
    end

    // Next candidate calculation
    always @(*) begin
        if (n_current < 9999) begin
            n_next = n_current + 1;
        end else begin
            n_next = n_current; // Stay at limit
        end
    end

    // State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            valid <= 0;
            done <= 0;
            n_current <= 0;
            found_match <= 0;
            x_fixed_reg <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    valid <= 0;
                    if (start) begin
                        n_current <= 100; // Start from 100 as per description (3-4 digits)
                        x_fixed_reg <= x_fixed;
                        found_match <= 0;
                        state <= CHECK;
                    end else begin
                        state <= IDLE;
                    end
                end

                CHECK: begin
                    // Calculation is combinational, we are ready
                    state <= ROTATE;
                end

                ROTATE: begin
                    // Rotation is combinational, we are ready
                    state <= VERIFY;
                end

                VERIFY: begin
                    // Compare product_fixed with rotated
                    // product_fixed is (N * X) >> 16 (Q16.16 -> Integer)
                    // rotated is integer
                    // Need to check if product is actually an integer (or close enough).
                    // But since inputs are integers and X is rational, we might need tolerance.
                    // However, the prompt implies exact match or simple truncation.
                    // Example: 135 * 2.6 = 351. Exact.
                    // Let's check exact match of integer part.
                    // Note: product_fixed is truncated. rotated is integer.
                    // Also check for overflow/negative? n and x are positive.
                    
                    if (product_fixed == rotated && product_fixed != 0) begin
                        result <= n_current;
                        valid <= 1'b1;
                        found_match <= 1'b1;
                    end else begin
                        valid <= 1'b0;
                    end
                    state <= NEXT;
                end

                NEXT: begin
                    if (n_current < 9999) begin
                        n_current <= n_next;
                        state <= CHECK;
                    end else begin
                        // End of range
                        if (!found_match) begin
                            result <= 0; // No match found
                            valid <= 1'b1; // Output 0 is valid in this context? Prompt says "output 0 if none" and valid high when result is valid.
                            // Let's assume "output 0" means result=0, and valid is set.
                        end else begin
                            // Match was found earlier, result holds the last found number.
                            // Prompt says: "If match, output N and continue searching". 
                            // It doesn't specify if we output ALL matches or just the LAST.
                            // "Accumulator for found numbers (output via result)" implies we keep the found value.
                            // Usually "accumulator" sums or holds. "Output via result" suggests single output register.
                            // If we want to output the *first* found, we can stop.
                            // If we want to output *all*, we need FIFO or streaming. 
                            // Given output reg [31:0] result, we likely overwrite with last found.
                            // Or maybe we stop on first match.
                            // "If match, output N and continue searching" -> implies overwrite.
                            // "If no match found ... output 0" -> implies final state.
                            // Let's refine: If we find a match, we output it. We continue.
                            // If we find another, we overwrite.
                            // At end, if found_match is true, result holds the last match.
                            // If no match, result is 0.
                            // Valid is high in DONE state if result is meaningful (or always high after search).
                            // Prompt: "valid high when result is valid". 
                            // If we found a match, result is valid. 
                            // If we finished and found nothing, result is 0, which is valid info (none found).
                            // Let's set valid=1 in DONE state regardless.
                        end
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    valid <= 1'b1; // Result is valid (either found number or 0)
                    // Stay here until reset
                end
            endcase
        end
    end

endmodule