module next_smallest_palindrome(
    input clk,
    input rst_n,
    input start,
    input [15:0] num_in,
    output reg [15:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE          = 5'b00001;
    localparam INCREMENT     = 5'b00010;
    localparam EXTRACT_DIGITS = 5'b00100;
    localparam CHECK_PALINDROME = 5'b01000;
    localparam VERIFY         = 5'b01001;
    localparam DONE          = 5'b10000;

    reg [4:0] state, next_state;

    // Datapath registers
    reg [15:0] current_val;       // Current candidate being checked
    reg [15:0] temp_val;          // Temporary value for digit extraction
    reg [3:0]  digit_count;       // Number of digits extracted
    reg [3:0]  digits[0:4];       // Array to store digits (max 5 digits for 65535)
    reg [3:0]  left_idx;          // Index for left side comparison
    reg [3:0]  right_idx;         // Index for right side comparison
    reg [4:0]  iteration_cnt;     // Safety counter for max iterations

    // Helper variables for digit extraction
    integer i;
    reg [15:0] div_result;
    reg [15:0] mod_result;

    // Combinational logic for digit extraction
    reg [3:0] e_digits[0:4];
    reg [3:0] e_count;
    always @(*) begin
        e_count = 0;
        if (current_val < 10) begin
            e_count = 1;
            e_digits[0] = current_val;
        end else if (current_val < 100) begin
            e_count = 2;
            e_digits[0] = current_val % 10;
            e_digits[1] = current_val / 10;
        end else if (current_val < 1000) begin
            e_count = 3;
            e_digits[0] = current_val % 10;
            e_digits[1] = (current_val / 10) % 10;
            e_digits[2] = current_val / 100;
        end else if (current_val < 10000) begin
            e_count = 4;
            e_digits[0] = current_val % 10;
            e_digits[1] = (current_val / 10) % 10;
            e_digits[2] = (current_val / 100) % 10;
            e_digits[3] = current_val / 1000;
        end else begin
            e_count = 5;
            e_digits[0] = current_val % 10;
            e_digits[1] = (current_val / 10) % 10;
            e_digits[2] = (current_val / 100) % 10;
            e_digits[3] = (current_val / 1000) % 10;
            e_digits[4] = current_val / 10000;
        end
    end

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'b0;
            done <= 1'b0;
            current_val <= 16'b0;
            temp_val <= 16'b0;
            digit_count <= 4'b0;
            left_idx <= 4'b0;
            right_idx <= 4'b0;
            iteration_cnt <= 5'b0;
            // Initialize digits array
            for (i = 0; i < 5; i = i + 1) begin
                digits[i] <= 4'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_val <= num_in;
                        iteration_cnt <= 5'b0;
                        next_state <= INCREMENT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INCREMENT: begin
                    if (iteration_cnt < 64) begin
                        current_val <= current_val + 1;
                        iteration_cnt <= iteration_cnt + 1;
                        next_state <= EXTRACT_DIGITS;
                    end else begin
                        next_state <= DONE;
                        result <= current_val;
                    end
                end

                EXTRACT_DIGITS: begin
                    // Initialize extraction
                    if (digit_count == 4'b0) begin
                        temp_val <= current_val;
                        digit_count <= e_count;
                    end
                    // Assign extracted digits to the array
                    for (i = 0; i < 5; i = i + 1) begin
                        digits[i] <= e_digits[i];
                    end
                    left_idx <= 4'b0;
                    right_idx <= digit_count - 1;
                    next_state <= CHECK_PALINDROME;
                end

                CHECK_PALINDROME: begin
                    reg match_flag;
                    match_flag <= (digits[left_idx] == digits[right_idx]);
                    if (!match_flag) begin
                        next_state <= INCREMENT;
                    end else begin
                        next_state <= VERIFY;
                    end
                end

                VERIFY: begin
                    if (match_flag) begin
                        left_idx <= left_idx + 1;
                        right_idx <= right_idx - 1;
                        wire signed [4:0] l_plus_1 = $signed({1'b0, left_idx}) + 1;
                        wire signed [4:0] r_minus_1 = $signed({1'b0, right_idx}) - 1;
                        if (l_plus_1 >= r_minus_1) begin
                            next_state <= DONE;
                        end else begin
                            next_state <= CHECK_PALINDROME;
                        end
                    end else begin
                        next_state <= INCREMENT;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    result <= current_val;
                    if (!start) begin
                        next_state <= IDLE;
                    end else begin
                        next_state <= DONE;
                    end
                end
            endcase
        end
    end
endmodule