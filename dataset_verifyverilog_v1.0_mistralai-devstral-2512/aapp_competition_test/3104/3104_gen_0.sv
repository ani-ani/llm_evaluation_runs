module partition_addition(
    input clk,
    input rst_n,
    input start,
    input [7:0] digits_in [0:23],
    input [4:0] len_in,
    input [15:0] target_sum,
    output reg [7:0] result_str [0:47],
    output reg [5:0] result_len,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] SEARCH = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Internal registers
    reg [7:0] digits [0:23];
    reg [4:0] len;
    reg [15:0] target;

    // Search state
    reg [4:0] current_pos;
    reg [15:0] current_sum;
    reg [4:0] path_len;
    reg [4:0] path_start [0:23];
    reg [4:0] path_end [0:23];
    reg found;

    // Output construction
    reg [7:0] output_str [0:47];
    reg [5:0] output_len;

    // Cycle counter for timeout
    reg [13:0] cycle_count;
    localparam [13:0] MAX_CYCLES = 14'd10000;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            cycle_count <= 14'd0;

            // Initialize digits array
            integer i;
            for (i = 0; i < 24; i = i + 1) begin
                digits[i] <= 8'd0;
            end
            len <= 5'd0;
            target <= 16'd0;

            // Initialize search state
            current_pos <= 5'd0;
            current_sum <= 16'd0;
            path_len <= 5'd0;
            for (i = 0; i < 24; i = i + 1) begin
                path_start[i] <= 5'd0;
                path_end[i] <= 5'd0;
            end
            found <= 1'b0;

            // Initialize output
            for (i = 0; i < 48; i = i + 1) begin
                output_str[i] <= 8'd0;
            end
            output_len <= 6'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 14'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    // Load input values
                    integer i;
                    for (i = 0; i < 24; i = i + 1) begin
                        digits[i] <= digits_in[i];
                    end
                    len <= len_in;
                    target <= target_sum;

                    // Initialize search
                    current_pos <= 5'd0;
                    current_sum <= 16'd0;
                    path_len <= 5'd0;
                    for (i = 0; i < 24; i = i + 1) begin
                        path_start[i] <= 5'd0;
                        path_end[i] <= 5'd0;
                    end
                    found <= 1'b0;

                    next_state <= SEARCH;
                end

                SEARCH: begin
                    cycle_count <= cycle_count + 14'd1;

                    // Backtracking search
                    if (!found && cycle_count < MAX_CYCLES) begin
                        if (current_pos == len) begin
                            // Check if we've reached the target sum
                            if (current_sum == target && path_len > 0) begin
                                found <= 1'b1;
                            end
                            next_state <= SEARCH;
                        end else begin
                            // Try all possible substrings starting at current_pos
                            reg [15:0] num;
                            reg [4:0] end_pos;
                            reg [7:0] digit;
                            reg [4:0] i;

                            // Calculate number for substring from current_pos to end_pos
                            num <= 16'd0;
                            for (i = current_pos; i < len; i = i + 1) begin
                                digit <= digits[i];
                                num <= num * 16'd10 + (digit - 8'd48);

                                // Check if adding this number would exceed target
                                if (current_sum + num <= target) begin
                                    // Store this partition
                                    path_start[path_len] <= current_pos;
                                    path_end[path_len] <= i;
                                    path_len <= path_len + 5'd1;

                                    // Update current state
                                    current_sum <= current_sum + num;
                                    current_pos <= i + 5'd1;

                                    // Move to next position
                                    next_state <= SEARCH;
                                    break;
                                end
                            end

                            // If no valid partition found, backtrack
                            if (i == len) begin
                                if (path_len > 0) begin
                                    path_len <= path_len - 5'd1;
                                    current_pos <= path_start[path_len];
                                    current_sum <= current_sum - num;
                                end else begin
                                    current_pos <= len; // Force completion
                                end
                            end
                        end
                    end else begin
                        next_state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    // Construct output string
                    integer i, j, k;
                    reg [7:0] char;

                    // Clear output
                    for (i = 0; i < 48; i = i + 1) begin
                        output_str[i] <= 8'd0;
                    end
                    output_len <= 6'd0;

                    if (found) begin
                        // Build the result string: term1+term2+...=target
                        k = 0;
                        for (i = 0; i < path_len; i = i + 1) begin
                            // Copy term
                            for (j = path_start[i]; j <= path_end[i]; j = j + 1) begin
                                output_str[k] <= digits[j];
                                k = k + 1;
                            end

                            // Add '+' if not last term
                            if (i < path_len - 1) begin
                                output_str[k] <= 8'd43; // '+'
                                k = k + 1;
                            end
                        end

                        // Add '=' and target
                        output_str[k] <= 8'd61; // '='
                        k = k + 1;

                        // Convert target to ASCII
                        reg [15:0] temp_target;
                        reg [7:0] digit_chars [0:4];
                        temp_target <= target;
                        for (i = 0; i < 5; i = i + 1) begin
                            digit_chars[i] <= 8'd48 + (temp_target % 10);
                            temp_target <= temp_target / 10;
                        end

                        // Output digits in reverse order
                        for (i = 4; i >= 0; i = i - 1) begin
                            if (digit_chars[i] != 8'd48 || k > 0) begin
                                output_str[k] <= digit_chars[i];
                                k = k + 1;
                            end
                        end

                        output_len <= k;
                    end

                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

    // Output assignment
    always @(posedge clk) begin
        integer i;
        for (i = 0; i < 48; i = i + 1) begin
            result_str[i] <= output_str[i];
        end
        result_len <= output_len;
    end

endmodule