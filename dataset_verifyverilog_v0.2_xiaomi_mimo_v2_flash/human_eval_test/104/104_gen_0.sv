module unique_digits(
    input clk,
    input rst_n,
    input start,
    input [13:0] in0, in1, in2, in3,
    output reg [13:0] out0, out1, out2, out3,
    output reg [2:0] count,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam PARSE_0 = 3'b001;
    localparam PARSE_1 = 3'b010;
    localparam PARSE_2 = 3'b011;
    localparam PARSE_3 = 3'b100;
    localparam FILTER = 3'b101;
    localparam SORT = 3'b110;
    localparam DONE = 3'b111;

    reg [2:0] state;
    reg [2:0] next_state;

    // Temporary storage
    reg [13:0] temp_nums [0:3]; // Stores valid numbers
    reg [1:0] valid_count;      // Number of valid numbers found
    reg [1:0] filter_idx;       // Index for filtering
    reg [1:0] sort_idx;         // Index for insertion sort
    reg [1:0] j;                // Inner loop index for sorting
    reg [13:0] key;             // Key for insertion sort

    // Digit extraction variables
    reg [13:0] current_num;
    reg [13:0] temp_val;
    reg [3:0] digit;
    reg [2:0] digit_idx;        // Max 4 digits (0-3)
    reg is_valid;
    reg [13:0] next_temp_val;
    reg [3:0] next_digit;
    reg [2:0] next_digit_idx;
    reg next_is_valid;

    // Sorting logic variables
    reg [13:0] temp_val_sort;
    reg [13:0] next_temp_nums [0:3];

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? PARSE_0 : IDLE;
            PARSE_0: next_state = (digit_idx == 4 || temp_val == 0) ? PARSE_1 : PARSE_0;
            PARSE_1: next_state = (digit_idx == 4 || temp_val == 0) ? PARSE_2 : PARSE_1;
            PARSE_2: next_state = (digit_idx == 4 || temp_val == 0) ? PARSE_3 : PARSE_2;
            PARSE_3: next_state = (digit_idx == 4 || temp_val == 0) ? FILTER : PARSE_3;
            FILTER: next_state = (filter_idx == 4) ? SORT : FILTER;
            SORT: next_state = (sort_idx == valid_count) ? DONE : SORT;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            out0 <= 14'b0;
            out1 <= 14'b0;
            out2 <= 14'b0;
            out3 <= 14'b0;
            count <= 3'b0;
            done <= 1'b0;
            // Reset internal state
            valid_count <= 2'b0;
            filter_idx <= 2'b0;
            sort_idx <= 2'b0;
            j <= 2'b0;
            key <= 14'b0;
            current_num <= 14'b0;
            temp_val <= 14'b0;
            digit <= 4'b0;
            digit_idx <= 3'b0;
            is_valid <= 1'b0;
            temp_nums[0] <= 14'b0;
            temp_nums[1] <= 14'b0;
            temp_nums[2] <= 14'b0;
            temp_nums[3] <= 14'b0;
        end else begin
            state <= next_state;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        // Initialize for parsing first number
                        current_num <= in0;
                        temp_val <= in0;
                        digit <= 4'b0;
                        digit_idx <= 3'b0;
                        is_valid <= 1'b1; // Assume valid until proven otherwise
                        valid_count <= 2'b0;
                        filter_idx <= 2'b0;
                        sort_idx <= 2'b0;
                    end
                end

                PARSE_0: begin
                    if (temp_val > 0 && digit_idx < 4) begin
                        temp_val <= next_temp_val;
                        digit <= next_digit;
                        digit_idx <= next_digit_idx;
                        is_valid <= next_is_valid;
                    end else if (temp_val == 0 && digit_idx == 0 && is_valid) begin
                         // Edge case for number 0, though inputs are 0-9999.
                         // If input is 0, it has no odd digits (or is even). Invalid.
                         // But if temp_val becomes 0 inside loop, we check what we found so far.
                         // Actually, if temp_val becomes 0, loop ends.
                         // If is_valid is still true, number is valid.
                    end
                    // Transition check is done in combinational block
                    // Logic to move to next number if done
                    if ((digit_idx == 4 || temp_val == 0) && is_valid) begin
                         temp_nums[0] <= current_num;
                         valid_count <= valid_count + 1;
                    end
                    // Prepare for next number if moving to PARSE_1
                    if ((digit_idx == 4 || temp_val == 0)) begin
                        current_num <= in1;
                        temp_val <= in1;
                        digit <= 4'b0;
                        digit_idx <= 3'b0;
                        is_valid <= 1'b1;
                    end
                end

                PARSE_1: begin
                    if (temp_val > 0 && digit_idx < 4) begin
                        temp_val <= next_temp_val;
                        digit <= next_digit;
                        digit_idx <= next_digit_idx;
                        is_valid <= next_is_valid;
                    end
                    if ((digit_idx == 4 || temp_val == 0) && is_valid) begin
                         temp_nums[valid_count] <= current_num;
                         valid_count <= valid_count + 1;
                    end
                    if ((digit_idx == 4 || temp_val == 0)) begin
                        current_num <= in2;
                        temp_val <= in2;
                        digit <= 4'b0;
                        digit_idx <= 3'b0;
                        is_valid <= 1'b1;
                    end
                end

                PARSE_2: begin
                    if (temp_val > 0 && digit_idx < 4) begin
                        temp_val <= next_temp_val;
                        digit <= next_digit;
                        digit_idx <= next_digit_idx;
                        is_valid <= next_is_valid;
                    end
                    if ((digit_idx == 4 || temp_val == 0) && is_valid) begin
                         temp_nums[valid_count] <= current_num;
                         valid_count <= valid_count + 1;
                    end
                    if ((digit_idx == 4 || temp_val == 0)) begin
                        current_num <= in3;
                        temp_val <= in3;
                        digit <= 4'b0;
                        digit_idx <= 3'b0;
                        is_valid <= 1'b1;
                    end
                end

                PARSE_3: begin
                    if (temp_val > 0 && digit_idx < 4) begin
                        temp_val <= next_temp_val;
                        digit <= next_digit;
                        digit_idx <= next_digit_idx;
                        is_valid <= next_is_valid;
                    end
                    if ((digit_idx == 4 || temp_val == 0) && is_valid) begin
                         temp_nums[valid_count] <= current_num;
                         valid_count <= valid_count + 1;
                    end
                    // Just wait for transition to FILTER
                end

                FILTER: begin
                    // Just state transition, buffer is already populated in PARSE states
                    filter_idx <= filter_idx + 1;
                end

                SORT: begin
                    // Insertion sort implementation
                    // We use sort_idx as the loop variable i (from 1 to n-1)
                    // We use j as the inner loop variable
                    // key is temp_nums[i]

                    if (j == 255) begin
                        // Initialize for next i
                        if (sort_idx < valid_count) begin
                            key <= temp_nums[sort_idx];
                            j <= sort_idx - 1; // This handles sort_idx=0 case too, though loop starts at 1 usually.
                        end else begin
                            // Done
                        end
                    end else begin
                        // Inner loop
                        if (j != 255 && temp_nums[j] > key) begin
                            // Shift
                            temp_nums[j+1] <= temp_nums[j];
                            if (j == 0) j <= 255; // Decrement to 255
                            else j <= j - 1;
                        end else begin
                            // Place key
                            temp_nums[j+1] <= key; // If j was 255, this is temp_nums[0]. If j was valid but <= key, this is temp_nums[j+1].
                            sort_idx <= sort_idx + 1;
                            j <= 255; // Reset for next iteration
                        end
                    end
                end

                DONE: begin
                    out0 <= temp_nums[0];
                    out1 <= temp_nums[1];
                    out2 <= temp_nums[2];
                    out3 <= temp_nums[3];
                    count <= valid_count;
                    done <= 1'b1;
                    // Reset sort_idx/j for next operation (optional, but good practice)
                    sort_idx <= 0;
                    j <= 255;
                end
            endcase
        end
    end

    // Combinational logic for digit extraction and validation
    // Used in PARSE states to update registers in the next cycle
    always @(*) begin
        if (temp_val > 0) begin
            next_temp_val = temp_val / 10;
            next_digit = temp_val % 10;
        end else begin
            next_temp_val = temp_val;
            next_digit = 0;
        end
        next_digit_idx = digit_idx + 1;

        // Check current digit (from previous cycle or initial state)
        // Note: In PARSE states, we update registers based on previous value.
        // So we look at 'digit' and 'is_valid' of the current cycle to compute next_is_valid.
        // However, we need to check the digit extracted from 'temp_val' (before division) which is 'digit'.
        // So if (digit % 2 == 0) and digit != 0, then invalid.
        // Note: if digit is 0, it's even, so invalid.
        if (digit[0] == 0) next_is_valid = 0;
        else next_is_valid = is_valid;
    end

endmodule
