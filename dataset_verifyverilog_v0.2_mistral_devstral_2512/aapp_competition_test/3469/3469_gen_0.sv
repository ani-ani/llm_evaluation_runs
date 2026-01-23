module probability_calculator (
    input clk,
    input rst_n,
    input start,
    input [19:0] g_mask,
    input [19:0] k_mask,
    input [7:0] g_len,
    input [7:0] k_len,
    input [15:0] p_fixed,
    output reg [31:0] result,
    output reg done
);

    // States
    typedef enum logic [3:0] {
        IDLE,
        BUILD_AUTOMATA,
        BUILD_MATRIX,
        SOLVE_GAUSSIAN,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [7:0] i, j, k;
    reg [7:0] row, col, pivot_row;
    reg [31:0] matrix [0:399][0:399];
    reg [31:0] solution [0:399];
    reg [31:0] temp, temp2, temp3;
    reg [31:0] p_q16;
    reg [7:0] g_transition [0:19][0:1];
    reg [7:0] k_transition [0:19][0:1];
    reg [7:0] g_prefix [0:19];
    reg [7:0] k_prefix [0:19];
    reg [7:0] num_states;

    // Initialize
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            result <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            row <= 0;
            col <= 0;
            pivot_row <= 0;
            p_q16 <= {16'd0, p_fixed};
            num_states <= 0;
            for (int x = 0; x < 400; x++) begin
                for (int y = 0; y < 400; y++) begin
                    matrix[x][y] <= 0;
                end
                solution[x] <= 0;
            end
        end else begin
            current_state <= next_state;
        end
    end

    // State machine
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = BUILD_AUTOMATA;
                    num_states = g_len * k_len;
                    // Initialize prefix functions
                    g_prefix[0] = 0;
                    k_prefix[0] = 0;
                    i = 0;
                    j = 0;
                end
            end
            BUILD_AUTOMATA: begin
                if (i < g_len) begin
                    if (j == 0) begin
                        g_prefix[i] = 0;
                        j = 1;
                    end else if (g_mask[i] == g_mask[g_prefix[j-1]]) begin
                        g_prefix[i] = g_prefix[j-1] + 1;
                        j = j + 1;
                    end else begin
                        g_prefix[i] = 0;
                        j = 1;
                    end
                    i = i + 1;
                end else if (i < g_len + k_len) begin
                    // Build k_prefix
                    if (j == 0) begin
                        k_prefix[i - g_len] = 0;
                        j = 1;
                    end else if (k_mask[i - g_len] == k_mask[k_prefix[j-1]]) begin
                        k_prefix[i - g_len] = k_prefix[j-1] + 1;
                        j = j + 1;
                    end else begin
                        k_prefix[i - g_len] = 0;
                        j = 1;
                    end
                    i = i + 1;
                end else if (i < 2*g_len + k_len) begin
                    // Build g_transition
                    if (j == 0) begin
                        g_transition[i - g_len - k_len][0] = g_prefix[i - g_len - k_len];
                        g_transition[i - g_len - k_len][1] = g_prefix[i - g_len - k_len];
                        j = 1;
                    end else if (g_mask[i - g_len - k_len] == 0) begin
                        g_transition[i - g_len - k_len][0] = j;
                        g_transition[i - g_len - k_len][1] = g_prefix[j];
                    end else begin
                        g_transition[i - g_len - k_len][0] = g_prefix[j];
                        g_transition[i - g_len - k_len][1] = j;
                    end
                    i = i + 1;
                end else if (i < 2*g_len + 2*k_len) begin
                    // Build k_transition
                    if (j == 0) begin
                        k_transition[i - 2*g_len - k_len][0] = k_prefix[i - 2*g_len - k_len];
                        k_transition[i - 2*g_len - k_len][1] = k_prefix[i - 2*g_len - k_len];
                        j = 1;
                    end else if (k_mask[i - 2*g_len - k_len] == 0) begin
                        k_transition[i - 2*g_len - k_len][0] = j;
                        k_transition[i - 2*g_len - k_len][1] = k_prefix[j];
                    end else begin
                        k_transition[i - 2*g_len - k_len][0] = k_prefix[j];
                        k_transition[i - 2*g_len - k_len][1] = j;
                    end
                    i = i + 1;
                end else begin
                    next_state = BUILD_MATRIX;
                    row = 0;
                    col = 0;
                end
            end
            BUILD_MATRIX: begin
                if (row < num_states) begin
                    if (col < num_states) begin
                        i = row / k_len;
                        j = row % k_len;
                        if (col == row) begin
                            matrix[row][col] = 32'h10000; // 1.0 in Q16.16
                        end else if (col == num_states - 1) begin
                            // Right-hand side
                            matrix[row][col] = 0;
                        end else begin
                            // Calculate transitions
                            k = col / k_len;
                            if (k == i && col % k_len == j) begin
                                matrix[row][col] = 32'h10000;
                            end else begin
                                matrix[row][col] = 0;
                            end
                        end
                        col = col + 1;
                    end else begin
                        col = 0;
                        row = row + 1;
                    end
                end else begin
                    next_state = SOLVE_GAUSSIAN;
                    row = 0;
                    col = 0;
                    pivot_row = 0;
                end
            end
            SOLVE_GAUSSIAN: begin
                if (row < num_states) begin
                    if (col < num_states) begin
                        // Partial pivoting
                        pivot_row = row;
                        for (k = row + 1; k < num_states; k = k + 1) begin
                            if (matrix[k][col] > matrix[pivot_row][col]) begin
                                pivot_row = k;
                            end
                        end
                        // Swap rows
                        if (pivot_row != row) begin
                            for (k = 0; k < num_states; k = k + 1) begin
                                temp = matrix[row][k];
                                matrix[row][k] = matrix[pivot_row][k];
                                matrix[pivot_row][k] = temp;
                            end
                        end
                        // Eliminate
                        for (k = row + 1; k < num_states; k = k + 1) begin
                            if (matrix[k][col] != 0) begin
                                temp = matrix[k][col];
                                temp2 = matrix[row][col];
                                for (i = col; i < num_states; i = i + 1) begin
                                    matrix[k][i] = matrix[k][i] * temp2 - matrix[row][i] * temp;
                                end
                            end
                        end
                        col = col + 1;
                    end else begin
                        col = 0;
                        row = row + 1;
                    end
                end else begin
                    // Back substitution
                    for (row = num_states - 1; row >= 0; row = row - 1) begin
                        temp = 0;
                        for (col = row + 1; col < num_states; col = col + 1) begin
                            temp = temp + matrix[row][col] * solution[col];
                        end
                        solution[row] = (matrix[row][num_states - 1] - temp) / matrix[row][row];
                    end
                    next_state = DONE;
                end
            end
            DONE: begin
                done = 1;
                result = solution[0];
            end
            default: next_state = IDLE;
        endcase
    end

endmodule