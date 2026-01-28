module nth_incremental_string(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] k,
    input wire [63:0] n,
    output reg done,
    output reg result_valid,
    output reg [4:0] result_char,
    output reg [8:0] result_idx,
    output reg finished,
    output reg no_solution
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] PREPARE   = 3'd1;
    localparam [2:0] SEARCH    = 3'd2;
    localparam [2:0] OUTPUT    = 3'd3;
    localparam [2:0] DONE      = 3'd4;

    reg [2:0] state, next_state;

    // Character count tracking (26 letters)
    reg [7:0] char_counts [0:25];
    reg [4:0] prev_char;
    reg [8:0] current_idx;
    reg [63:0] current_n;
    reg [63:0] total_strings;

    // Stack for DFS (max depth 351)
    reg [4:0] stack_char [0:350];
    reg [7:0] stack_counts [0:350][0:25];
    reg [4:0] stack_prev [0:350];
    reg [8:0] stack_idx [0:350];
    reg [8:0] stack_ptr;

    // Temporary variables for counting
    reg [63:0] branch_count;
    reg [4:0] candidate_char;
    reg [7:0] temp_counts [0:25];
    reg [4:0] temp_prev;

    // Initialize all registers
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            result_valid <= 1'b0;
            result_char <= 5'd0;
            result_idx <= 9'd0;
            finished <= 1'b0;
            no_solution <= 1'b0;
            current_idx <= 9'd0;
            current_n <= 64'd0;
            total_strings <= 64'd0;
            stack_ptr <= 9'd0;
            prev_char <= 5'd26; // Invalid initial value
            for (i = 0; i < 26; i = i + 1) begin
                char_counts[i] <= 8'd0;
            end
            for (i = 0; i < 351; i = i + 1) begin
                stack_char[i] <= 5'd0;
                stack_prev[i] <= 5'd0;
                stack_idx[i] <= 9'd0;
                for (j = 0; j < 26; j = j + 1) begin
                    stack_counts[i][j] <= 8'd0;
                end
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PREPARE;
                end
            end

            PREPARE: begin
                // Validate k and initialize
                if (k < 5'd1 || k > 5'd26) begin
                    no_solution = 1'b1;
                    next_state = DONE;
                end else begin
                    // Calculate total possible strings (simplified for example)
                    // In a real implementation, this would compute the exact count
                    total_strings = 64'd1;
                    for (i = 1; i <= k; i = i + 1) begin
                        total_strings = total_strings * (26 - i + 1);
                    end

                    if (n > total_strings) begin
                        no_solution = 1'b1;
                        next_state = DONE;
                    end else begin
                        current_n = n;
                        current_idx = 9'd0;
                        prev_char = 5'd26; // No previous character
                        for (i = 0; i < 26; i = i + 1) begin
                            char_counts[i] = 8'd0;
                        end
                        next_state = SEARCH;
                    end
                end
            end

            SEARCH: begin
                if (current_idx == 9'd0) begin
                    // First character - try all possibilities
                    candidate_char = 5'd0;
                    while (candidate_char < 5'd26) begin
                        // Check if we can use this character (count constraints)
                        // For simplicity, assume we can use any character once
                        if (1'b1) begin
                            // Calculate number of valid completions for this branch
                            branch_count = 64'd1;
                            for (i = 1; i <= k; i = i + 1) begin
                                if (i == 1) begin
                                    branch_count = branch_count * (25 - i + 1);
                                end else begin
                                    branch_count = branch_count * (26 - i + 1);
                                end
                            end

                            if (current_n <= branch_count) begin
                                // Select this character
                                stack_char[stack_ptr] = candidate_char;
                                stack_prev[stack_ptr] = prev_char;
                                stack_idx[stack_ptr] = current_idx;
                                for (i = 0; i < 26; i = i + 1) begin
                                    stack_counts[stack_ptr][i] = char_counts[i];
                                end
                                stack_ptr = stack_ptr + 9'd1;

                                char_counts[candidate_char] = char_counts[candidate_char] + 8'd1;
                                prev_char = candidate_char;
                                current_idx = current_idx + 9'd1;
                                next_state = SEARCH;
                                break;
                            end else begin
                                current_n = current_n - branch_count;
                            end
                        end
                        candidate_char = candidate_char + 5'd1;
                    end

                    if (candidate_char == 5'd26) begin
                        // No solution found
                        no_solution = 1'b1;
                        next_state = DONE;
                    end
                end else begin
                    // Subsequent characters - must differ from previous
                    candidate_char = 5'd0;
                    while (candidate_char < 5'd26) begin
                        if (candidate_char != prev_char) begin
                            // Check count constraints (simplified)
                            if (1'b1) begin
                                // Calculate branch count
                                branch_count = 64'd1;
                                for (i = 1; i <= k; i = i + 1) begin
                                    if (i == 1) begin
                                        branch_count = branch_count * (25 - i + 1);
                                    end else begin
                                        branch_count = branch_count * (26 - i + 1);
                                    end
                                end

                                if (current_n <= branch_count) begin
                                    // Select this character
                                    stack_char[stack_ptr] = candidate_char;
                                    stack_prev[stack_ptr] = prev_char;
                                    stack_idx[stack_ptr] = current_idx;
                                    for (i = 0; i < 26; i = i + 1) begin
                                        stack_counts[stack_ptr][i] = char_counts[i];
                                    end
                                    stack_ptr = stack_ptr + 9'd1;

                                    char_counts[candidate_char] = char_counts[candidate_char] + 8'd1;
                                    prev_char = candidate_char;
                                    current_idx = current_idx + 9'd1;
                                    next_state = SEARCH;
                                    break;
                                end else begin
                                    current_n = current_n - branch_count;
                                end
                            end
                        end
                        candidate_char = candidate_char + 5'd1;
                    end

                    if (candidate_char == 5'd26) begin
                        // Backtrack
                        if (stack_ptr > 9'd0) begin
                            stack_ptr = stack_ptr - 9'd1;
                            current_idx = stack_idx[stack_ptr];
                            prev_char = stack_prev[stack_ptr];
                            for (i = 0; i < 26; i = i + 1) begin
                                char_counts[i] = stack_counts[stack_ptr][i];
                            end
                            next_state = SEARCH;
                        end else begin
                            no_solution = 1'b1;
                            next_state = DONE;
                        end
                    end
                end

                // Check if we've built the complete string
                if (current_idx == (k*(k+1))/2) begin
                    next_state = OUTPUT;
                end
            end

            OUTPUT: begin
                if (result_idx < current_idx) begin
                    result_char = stack_char[result_idx];
                    result_idx = result_idx + 9'd1;
                    result_valid = 1'b1;
                    if (result_idx == current_idx) begin
                        finished = 1'b1;
                        done = 1'b1;
                        next_state = DONE;
                    end
                end else begin
                    finished = 1'b1;
                    done = 1'b1;
                    next_state = DONE;
                end
            end

            DONE: begin
                // Stay in DONE until next start
                if (start) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule