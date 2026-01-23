module make_palindrome(
    input clk,
    input rst_n,
    input start,
    input [4:0] str_len,
    input [15:0][7:0] str_data,
    output reg [4:0] result_len,
    output reg [31:0][7:0] result_data,
    output reg done
);

    // States
    localparam IDLE = 2'b00;
    localparam FIND_SUFFIX = 2'b01;
    localparam BUILD_RESULT = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state;
    reg [4:0] suffix_len;
    reg [4:0] check_len;
    reg [4:0] i_cnt;
    reg [4:0] j_cnt;
    reg mismatch;
    reg [4:0] current_len;
    
    // Combinational logic for palindrome checking
    wire is_palindrome;
    wire [4:0] left_idx;
    wire [4:0] right_idx;
    
    assign left_idx = i_cnt;
    assign right_idx = current_len - 1 - i_cnt;
    
    // Only valid if indices don't cross
    assign is_palindrome = (str_data[left_idx] == str_data[right_idx]) && (left_idx < right_idx);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_len <= 5'd0;
            result_data <= 1024'b0;
            suffix_len <= 5'd0;
            check_len <= 5'd0;
            i_cnt <= 5'd0;
            mismatch <= 1'b0;
            current_len <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (str_len == 5'd0) begin
                            result_len <= 5'd0;
                            done <= 1'b1;
                            state <= DONE;
                        end else begin
                            // Start finding suffix
                            current_len <= str_len;
                            suffix_len <= str_len;
                            check_len <= str_len;
                            i_cnt <= 5'd0;
                            mismatch <= 1'b0;
                            state <= FIND_SUFFIX;
                        end
                    end
                end

                FIND_SUFFIX: begin
                    // Check if current substring [0 to check_len-1] is palindrome
                    if (i_cnt < check_len) begin
                        if (!mismatch) begin
                            if (str_data[i_cnt] != str_data[check_len - 1 - i_cnt]) begin
                                mismatch <= 1'b1;
                            end
                        end
                        i_cnt <= i_cnt + 1'b1;
                    end else begin
                        // Finished checking current length
                        if (!mismatch) begin
                            // Found palindrome suffix
                            suffix_len <= check_len;
                            // Transition to build result
                            i_cnt <= 5'd0;
                            state <= BUILD_RESULT;
                        end else begin
                            // Try shorter suffix
                            if (check_len > 5'd1) begin
                                check_len <= check_len - 1'b1;
                                i_cnt <= 5'd0;
                                mismatch <= 1'b0;
                            end else begin
                                // check_len == 1 is always palindrome
                                suffix_len <= 5'd1;
                                i_cnt <= 5'd0;
                                state <= BUILD_RESULT;
                            end
                        end
                    end
                end

                BUILD_RESULT: begin
                    // This state executes in one cycle (unrolled logic)
                    // Copy input string to result
                    result_len <= (str_len << 1) - suffix_len;
                    
                    // Copy original string
                    result_data[0] <= str_data[0];
                    result_data[1] <= str_data[1];
                    result_data[2] <= str_data[2];
                    result_data[3] <= str_data[3];
                    result_data[4] <= str_data[4];
                    result_data[5] <= str_data[5];
                    result_data[6] <= str_data[6];
                    result_data[7] <= str_data[7];
                    result_data[8] <= str_data[8];
                    result_data[9] <= str_data[9];
                    result_data[10] <= str_data[10];
                    result_data[11] <= str_data[11];
                    result_data[12] <= str_data[12];
                    result_data[13] <= str_data[13];
                    result_data[14] <= str_data[14];
                    result_data[15] <= str_data[15];
                    
                    // Append reversed prefix (prefix is 0 to str_len-suffix_len-1)
                    // str_len - suffix_len = length of prefix
                    // Result indices start at str_len
                    
                    // We need to copy str_data[0] -> result[str_len + (prefix_len-1)]
                    // str_data[1] -> result[str_len + (prefix_len-2)]
                    // ...
                    
                    // Unrolled for all 16 possible positions
                    // Only valid if index < result_len
                    
                    if (str_len >= 5'd1 && str_len > suffix_len) result_data[str_len + str_len - suffix_len - 1] <= str_data[0];
                    if (str_len >= 5'd2 && str_len > suffix_len + 1) result_data[str_len + str_len - suffix_len - 2] <= str_data[1];
                    if (str_len >= 5'd3 && str_len > suffix_len + 2) result_data[str_len + str_len - suffix_len - 3] <= str_data[2];
                    if (str_len >= 5'd4 && str_len > suffix_len + 3) result_data[str_len + str_len - suffix_len - 4] <= str_data[3];
                    if (str_len >= 5'd5 && str_len > suffix_len + 4) result_data[str_len + str_len - suffix_len - 5] <= str_data[4];
                    if (str_len >= 5'd6 && str_len > suffix_len + 5) result_data[str_len + str_len - suffix_len - 6] <= str_data[5];
                    if (str_len >= 5'd7 && str_len > suffix_len + 6) result_data[str_len + str_len - suffix_len - 7] <= str_data[6];
                    if (str_len >= 5'd8 && str_len > suffix_len + 7) result_data[str_len + str_len - suffix_len - 8] <= str_data[7];
                    if (str_len >= 5'd9 && str_len > suffix_len + 8) result_data[str_len + str_len - suffix_len - 9] <= str_data[8];
                    if (str_len >= 5'd10 && str_len > suffix_len + 9) result_data[str_len + str_len - suffix_len - 10] <= str_data[9];
                    if (str_len >= 5'd11 && str_len > suffix_len + 10) result_data[str_len + str_len - suffix_len - 11] <= str_data[10];
                    if (str_len >= 5'd12 && str_len > suffix_len + 11) result_data[str_len + str_len - suffix_len - 12] <= str_data[11];
                    if (str_len >= 5'd13 && str_len > suffix_len + 12) result_data[str_len + str_len - suffix_len - 13] <= str_data[12];
                    if (str_len >= 5'd14 && str_len > suffix_len + 13) result_data[str_len + str_len - suffix_len - 14] <= str_data[13];
                    if (str_len >= 5'd15 && str_len > suffix_len + 14) result_data[str_len + str_len - suffix_len - 15] <= str_data[14];
                    if (str_len >= 5'd16 && str_len > suffix_len + 15) result_data[str_len + str_len - suffix_len - 16] <= str_data[15];

                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule