module circular_shift (
    input clk,
    input rst_n,
    input start,
    input [31:0] x,
    input [7:0] shift,
    output reg [31:0] result,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam EXTRACT = 3'b001;
    localparam SHIFT = 3'b010;
    localparam RECONSTRUCT = 3'b011;
    localparam FINISH = 3'b100;

    reg [2:0] state;
    reg [3:0] digits [0:9];       // BCD digits
    reg [3:0] res_digits [0:9];   // Shifted BCD digits
    reg [3:0] digit_count;        // Total number of digits (max 10)
    reg [7:0] idx;                // Index for iteration
    reg [31:0] temp_x;            // Temporary value for division
    reg [7:0] eff_shift;          // Effective shift amount
    reg reversal_flag;            // Flag if shift >= len
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            digit_count <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= EXTRACT;
                        temp_x <= x;
                        digit_count <= 0;
                        // Clear digits array
                        for (i = 0; i < 10; i = i + 1) digits[i] <= 0;
                    end
                end

                EXTRACT: begin
                    // Extract digits using division/modulo
                    // Handles the edge case of x = 0 separately
                    if (temp_x == 0 && digit_count > 0) begin
                        state <= SHIFT;
                        idx <= 0;
                        
                        // Calculate effective shift and determine if reversal is needed
                        if (shift >= digit_count) begin
                            reversal_flag <= 1;
                        end else begin
                            reversal_flag <= 0;
                            // Calculate shift % digit_count
                            // Since digit_count is small (<=10), we can do this via repeated subtraction or built-in mod
                            // To be safe and generic for synthesis:
                            eff_shift <= shift % digit_count;
                        end
                    end else if (digit_count < 10) begin
                        // Extract one digit per cycle
                        digits[digit_count] <= temp_x % 10;
                        temp_x <= temp_x / 10;
                        digit_count <= digit_count + 1;
                    end else begin
                        // Fallback for max digits reached
                        state <= SHIFT;
                        idx <= 0;
                        if (shift >= digit_count) reversal_flag <= 1;
                        else begin
                            reversal_flag <= 0;
                            eff_shift <= shift % digit_count;
                        end
                    end
                end

                SHIFT: begin
                    // Perform the shift or reversal
                    if (idx < digit_count) begin
                        if (reversal_flag) begin
                            // Reversal: result_digit[i] = original_digit[len - 1 - i]
                            res_digits[idx] <= digits[digit_count - 1 - idx];
                        end else begin
                            // Rotation: result_digit[i] = original_digit[(i + shift) % len]
                            // Note: index math requires modulo. 
                            // Since we are iterating idx from 0 to len-1, and shift < len, 
                            // (idx + eff_shift) can be in range [0, 2*len-2].
                            // We can use a pre-calculated index or simple math.
                            // Let's compute the source index: (idx + eff_shift)
                            // If >= len, subtract len.
                            // Or use modulo operator which synthesizes well for small constants.
                            res_digits[idx] <= digits[(idx + eff_shift) % digit_count];
                        end
                        idx <= idx + 1;
                    end else begin
                        state <= RECONSTRUCT;
                        idx <= 0;
                        result <= 0;
                    end
                end

                RECONSTRUCT: begin
                    // Convert BCD array back to integer: result = result * 10 + digit
                    if (idx < digit_count) begin
                        result <= result * 10 + res_digits[idx];
                        idx <= idx + 1;
                    end else begin
                        // If digit_count was 0 (input was 0), result stays 0
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule