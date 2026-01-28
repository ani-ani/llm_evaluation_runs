module check_same_chars (
    input clk,
    input rst_n,
    input start,
    input [7:0] char [0:7],
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] COMPARE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [2:0] counter;        // 0-7 for character indices
    reg [7:0] first_char;     // Reference character
    reg mismatch_found;       // Flag for any mismatch

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            counter <= 3'd0;
            first_char <= 8'd0;
            mismatch_found <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;           // Clear done
                    if (start) begin
                        state <= LOAD;
                        mismatch_found <= 1'b0;  // Reset mismatch flag
                        counter <= 3'd0;     // Start at index 0
                    end
                end

                LOAD: begin
                    // Capture char[0] as reference
                    first_char <= char[0];
                    counter <= 3'd1;        // Move to index 1 for comparison
                    state <= COMPARE;
                    result <= 1'b1;         // Assume all same initially
                end

                COMPARE: begin
                    // Compare current character against first_char
                    if (char[counter] != first_char) begin
                        mismatch_found <= 1'b1;
                        result <= 1'b0;
                    end

                    // Check if we've processed all 8 characters
                    if (counter == 3'd7) begin
                        // Final comparison complete
                        state <= IDLE;
                        done <= 1'b1;
                        // If no mismatches found, result stays 1
                    end else begin
                        // Continue to next character
                        counter <= counter + 3'd1;
                    end
                end

                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule