module bracket_validator (
    input clk,
    input rst_n,
    input start,
    input [127:0] brackets,
    input [4:0] length,
    output reg valid,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg signed [5:0] counter; // Signed counter to detect negative values easily
    reg [4:0] index;
    reg internal_valid;

    // Current character extraction (index determines which 8-bit char to read)
    wire [7:0] current_char;
    assign current_char = brackets[(index * 8) +: 8];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            done <= 1'b0;
            counter <= 6'sd0;
            index <= 5'd0;
            internal_valid <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        counter <= 6'sd0;
                        index <= 5'd0;
                        internal_valid <= 1'b1;
                        // If length is 0, we go directly to DONE, otherwise PROCESSING
                        if (length == 5'd0) begin
                            state <= DONE;
                            valid <= 1'b1;
                            done <= 1'b1;
                        end else begin
                            state <= PROCESSING;
                        end
                    end
                end

                PROCESSING: begin
                    // Process current character
                    if (current_char == 8'h3C) begin // '<'
                        counter <= counter + 1;
                    end else if (current_char == 8'h3E) begin // '>'
                        if (counter == 6'sd0) begin
                            // Underflow detected
                            internal_valid <= 1'b0;
                            counter <= 6'sd0; // Keep it 0 or clamp to prevent overflow logic issues
                        end else begin
                            counter <= counter - 1;
                        end
                    end
                    // If it's not '<' or '>', we ignore it (valid remains true unless underflow occurred)
                    // Note: Requirement implies checking specifically for bracket correctness.
                    // Non-bracket characters are ignored but do not invalidate the sequence based on "nesting" logic,
                    // but typically in validators, any other char might be considered invalid.
                    // Based on description "checks if a string of angle brackets has correct nesting",
                    // we assume only angle brackets exist or non-brackets are ignored.
                    // If non-brackets should invalidate, we'd add: else internal_valid <= 1'b0;
                    // Given the strict description of '<' and '>', I will treat non-brackets as valid (ignored) unless specified otherwise.
                    // However, to be safe and strict, if the input contains anything other than < or >, should it be valid?
                    // Let's assume only < and > are processed, others are ignored for this specific nesting check.

                    index <= index + 1;

                    // Check termination condition
                    if (index == length - 1) begin
                        state <= DONE;
                        done <= 1'b1;
                        // Final validity check
                        if (internal_valid && (counter == 6'sd0)) begin
                            valid <= 1'b1;
                        end else begin
                            valid <= 1'b0;
                        end
                    end
                end

                DONE: begin
                    // Wait for reset or next start (handled in IDLE transition)
                    // If start comes while in DONE, logic below handles it, but standard practice is to go to IDLE or stay.
                    // We stay here until reset or explicit start.
                    done <= 1'b1; // Keep done high until reset
                    if (start) begin
                        // Restart logic if start is asserted in DONE state
                        counter <= 6'sd0;
                        index <= 5'd0;
                        internal_valid <= 1'b1;
                        done <= 1'b0;
                        if (length == 5'd0) begin
                            state <= DONE;
                            valid <= 1'b1;
                            done <= 1'b1;
                        end else begin
                            state <= PROCESSING;
                            valid <= 1'b0; // Reset valid during processing
                        end
                    end else if (!rst_n) begin
                        // Handled by global reset
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule