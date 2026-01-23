module code_cracker (
    input clk,
    input rst_n,
    input start,
    input [3:0] row_addr,
    input [3:0] col_addr,
    input [3:0] data_in,
    input load_en,
    output reg [15:0] count,
    output reg done
);

    // Define states
    typedef enum logic [2:0] {
        IDLE,
        LOAD_GRID,
        FIND_ZEROS,
        SEARCH,
        VALIDATE,
        DONE
    } state_t;

    state_t state, next_state;

    // Grid storage (4x4)
    reg [3:0] grid [0:3][0:3];

    // Zero positions storage (max 8)
    reg [3:0] zero_positions [0:7];
    reg [2:0] zero_count;

    // Backtracking stack
    reg [3:0] stack [0:7];
    reg [2:0] stack_ptr;

    // Current position being filled
    reg [2:0] current_zero_idx;

    // Digit being tried (1-9)
    reg [3:0] current_digit;

    // Temporary variables for validation
    reg [3:0] l, u, r;
    reg valid;

    // Initialize state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 0;
            done <= 0;
            zero_count <= 0;
            current_zero_idx <= 0;
            current_digit <= 1;
            stack_ptr <= 0;
            for (int i = 0; i < 4; i++) begin
                for (int j = 0; j < 4; j++) begin
                    grid[i][j] <= 0;
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
                    next_state = LOAD_GRID;
                end
            end

            LOAD_GRID: begin
                if (load_en) begin
                    grid[row_addr][col_addr] = data_in;
                end
                next_state = FIND_ZEROS;
            end

            FIND_ZEROS: begin
                // Find all zero positions
                zero_count = 0;
                for (int i = 0; i < 4; i++) begin
                    for (int j = 0; j < 4; j++) begin
                        if (grid[i][j] == 0) begin
                            zero_positions[zero_count] = {i, j};
                            zero_count = zero_count + 1;
                        end
                    end
                end
                if (zero_count == 0) begin
                    next_state = DONE;
                end else begin
                    current_zero_idx = 0;
                    current_digit = 1;
                    next_state = SEARCH;
                end
            end

            SEARCH: begin
                if (current_zero_idx < zero_count) begin
                    // Try current_digit
                    grid[zero_positions[current_zero_idx][3:2]][zero_positions[current_zero_idx][1:0]] = current_digit;
                    next_state = VALIDATE;
                end else begin
                    // All zeros filled, check if valid
                    next_state = VALIDATE;
                end
            end

            VALIDATE: begin
                valid = 1;
                // Check row uniqueness
                for (int i = 0; i < 4; i++) begin
                    reg [3:0] row_digits [0:3];
                    for (int j = 0; j < 4; j++) begin
                        row_digits[j] = grid[i][j];
                    end
                    // Check for duplicates
                    for (int j = 0; j < 4; j++) begin
                        for (int k = j+1; k < 4; k++) begin
                            if (row_digits[j] != 0 && row_digits[k] != 0 && row_digits[j] == row_digits[k]) begin
                                valid = 0;
                            end
                        end
                    end
                end

                // Check L-shape rule
                for (int i = 1; i < 4; i++) begin
                    for (int j = 0; j < 3; j++) begin
                        l = grid[i][j];
                        u = grid[i-1][j];
                        r = grid[i][j+1];
                        if (l != 0 && u != 0 && r != 0) begin
                            if (!(u == l * r || u == l + r || u == (l > r ? l - r : r - l) || (r != 0 && u == l / r) || (l != 0 && u == r / l))) begin
                                valid = 0;
                            end
                        end
                    end
                end

                if (valid) begin
                    if (current_zero_idx == zero_count - 1) begin
                        // Found a valid configuration
                        count = count + 1;
                        next_state = SEARCH;
                        // Backtrack
                        if (current_zero_idx > 0) begin
                            current_zero_idx = current_zero_idx - 1;
                            current_digit = stack[stack_ptr] + 1;
                            stack_ptr = stack_ptr - 1;
                        end else begin
                            next_state = DONE;
                        end
                    end else begin
                        // Move to next zero
                        stack[stack_ptr] = current_digit;
                        stack_ptr = stack_ptr + 1;
                        current_zero_idx = current_zero_idx + 1;
                        current_digit = 1;
                        next_state = SEARCH;
                    end
                end else begin
                    // Try next digit
                    if (current_digit < 9) begin
                        current_digit = current_digit + 1;
                        next_state = SEARCH;
                    end else begin
                        // Backtrack
                        if (current_zero_idx > 0) begin
                            current_zero_idx = current_zero_idx - 1;
                            current_digit = stack[stack_ptr] + 1;
                            stack_ptr = stack_ptr - 1;
                            next_state = SEARCH;
                        end else begin
                            next_state = DONE;
                        end
                    end
                end
            end

            DONE: begin
                done = 1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule