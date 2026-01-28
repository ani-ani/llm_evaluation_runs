module palindrome_checker(
    input clk,
    input rst_n,
    input start,
    input [7:0] str [0:7],
    input [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECKING = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    reg [1:0] state;
    reg [2:0] i;  // Index counter
    reg [2:0] comparisons_needed;  // Number of comparisons to make
    reg [2:0] comparisons_done;  // Number of comparisons completed
    reg [7:0] left_char;  // Left character in comparison
    reg [7:0] right_char;  // Right character in comparison
    reg mismatch_found;  // Flag for mismatch

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            i <= 3'd0;
            comparisons_needed <= 3'd0;
            comparisons_done <= 3'd0;
            left_char <= 8'd0;
            right_char <= 8'd0;
            mismatch_found <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Calculate number of comparisons needed
                        if (len == 4'd0) begin
                            comparisons_needed <= 3'd0;  // Empty string
                        end else begin
                            comparisons_needed <= (len - 4'd1) / 2;
                        end
                        i <= 3'd0;
                        comparisons_done <= 3'd0;
                        mismatch_found <= 1'b0;
                        state <= CHECKING;
                    end
                end

                CHECKING: begin
                    if (comparisons_needed == 3'd0) begin
                        // Empty string is palindrome
                        result <= 1'b1;
                        state <= COMPLETE;
                    end else if (comparisons_done < comparisons_needed) begin
                        // Load characters to compare
                        left_char <= str[i];
                        right_char <= str[len - 4'd1 - i];

                        // Check for mismatch
                        if (left_char != right_char) begin
                            mismatch_found <= 1'b1;
                        end

                        // Increment counters
                        i <= i + 3'd1;
                        comparisons_done <= comparisons_done + 3'd1;
                    end else begin
                        // All comparisons done
                        if (mismatch_found) begin
                            result <= 1'b0;
                        end else begin
                            result <= 1'b1;
                        end
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule