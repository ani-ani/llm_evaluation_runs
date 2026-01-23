module domino_solver (
    input clk,
    input rst_n,
    input start,
    input [1:0] K,
    input [3:0][3:0][7:0] grid,
    output reg [15:0] min_sum,
    output reg done
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        CALC_TOTAL,
        GEN_DOMINOS,
        FIND_BEST,
        DONE
    } state_t;

    state_t state = IDLE;
    reg [15:0] total_sum = 0;
    reg [15:0] current_sum = 0;
    reg [15:0] best_sum = 0;
    reg [15:0] domino_count = 0;
    reg [15:0] domino_idx = 0;
    reg [15:0] cell_mask = 0;
    reg [15:0] temp_mask = 0;
    reg [15:0] i = 0;
    reg [15:0] j = 0;
    reg [15:0] k = 0;
    reg [15:0] l = 0;
    reg [15:0] m = 0;
    reg [15:0] n = 0;
    reg [15:0] domino_value = 0;
    reg [15:0] max_covered = 0;
    reg [15:0] covered_sum = 0;
    reg [15:0] best_covered = 0;
    reg [15:0] temp_covered = 0;
    reg [15:0] temp_best = 0;
    reg [15:0] temp_cell_mask = 0;
    reg [15:0] temp_domino_idx = 0;
    reg [15:0] temp_domino_count = 0;
    reg [15:0] temp_i = 0;
    reg [15:0] temp_j = 0;
    reg [15:0] temp_k = 0;
    reg [15:0] temp_l = 0;
    reg [15:0] temp_m = 0;
    reg [15:0] temp_n = 0;
    reg [15:0] temp_domino_value = 0;
    reg [15:0] temp_max_covered = 0;
    reg [15:0] temp_covered_sum = 0;
    reg [15:0] temp_best_covered = 0;
    reg [15:0] temp_temp_covered = 0;
    reg [15:0] temp_temp_best = 0;
    reg [15:0] temp_temp_cell_mask = 0;
    reg [15:0] temp_temp_domino_idx = 0;
    reg [15:0] temp_temp_domino_count = 0;
    reg [15:0] temp_temp_i = 0;
    reg [15:0] temp_temp_j = 0;
    reg [15:0] temp_temp_k = 0;
    reg [15:0] temp_temp_l = 0;
    reg [15:0] temp_temp_m = 0;
    reg [15:0] temp_temp_n = 0;
    reg [15:0] temp_temp_domino_value = 0;
    reg [15:0] temp_temp_max_covered = 0;
    reg [15:0] temp_temp_covered_sum = 0;
    reg [15:0] temp_temp_best_covered = 0;

    // Domino list (48 dominoes: 24 horizontal + 24 vertical)
    reg [7:0] domino_list [0:47][0:1];
    reg [7:0] domino_values [0:47];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            total_sum <= 0;
            current_sum <= 0;
            best_sum <= 0;
            domino_count <= 0;
            domino_idx <= 0;
            cell_mask <= 0;
            temp_mask <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            l <= 0;
            m <= 0;
            n <= 0;
            domino_value <= 0;
            max_covered <= 0;
            covered_sum <= 0;
            best_covered <= 0;
            temp_covered <= 0;
            temp_best <= 0;
            temp_cell_mask <= 0;
            temp_domino_idx <= 0;
            temp_domino_count <= 0;
            temp_i <= 0;
            temp_j <= 0;
            temp_k <= 0;
            temp_l <= 0;
            temp_m <= 0;
            temp_n <= 0;
            temp_domino_value <= 0;
            temp_max_covered <= 0;
            temp_covered_sum <= 0;
            temp_best_covered <= 0;
            temp_temp_covered <= 0;
            temp_temp_best <= 0;
            temp_temp_cell_mask <= 0;
            temp_temp_domino_idx <= 0;
            temp_temp_domino_count <= 0;
            temp_temp_i <= 0;
            temp_temp_j <= 0;
            temp_temp_k <= 0;
            temp_temp_l <= 0;
            temp_temp_m <= 0;
            temp_temp_n <= 0;
            temp_temp_domino_value <= 0;
            temp_temp_max_covered <= 0;
            temp_temp_covered_sum <= 0;
            temp_temp_best_covered <= 0;
            min_sum <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CALC_TOTAL;
                        total_sum <= 0;
                        i <= 0;
                        j <= 0;
                    end
                end
                CALC_TOTAL: begin
                    if (i < 4) begin
                        if (j < 4) begin
                            total_sum <= total_sum + grid[i][j];
                            j <= j + 1;
                        end else begin
                            j <= 0;
                            i <= i + 1;
                        end
                    end else begin
                        state <= GEN_DOMINOS;
                        domino_idx <= 0;
                        i <= 0;
                        j <= 0;
                    end
                end
                GEN_DOMINOS: begin
                    if (domino_idx < 48) begin
                        if (domino_idx < 24) begin
                            // Horizontal dominoes
                            domino_list[domino_idx][0] <= i * 4 + j;
                            domino_list[domino_idx][1] <= i * 4 + j + 1;
                            domino_values[domino_idx] <= grid[i][j] + grid[i][j + 1];
                            if (j < 3) begin
                                j <= j + 1;
                            end else begin
                                j <= 0;
                                i <= i + 1;
                            end
                        end else begin
                            // Vertical dominoes
                            domino_list[domino_idx][0] <= i * 4 + j;
                            domino_list[domino_idx][1] <= (i + 1) * 4 + j;
                            domino_values[domino_idx] <= grid[i][j] + grid[i + 1][j];
                            if (j < 3) begin
                                j <= j + 1;
                            end else begin
                                j <= 0;
                                i <= i + 1;
                            end
                        end
                        domino_idx <= domino_idx + 1;
                    end else begin
                        state <= FIND_BEST;
                        domino_count <= 0;
                        best_covered <= 0;
                        cell_mask <= 0;
                        i <= 0;
                        j <= 0;
                        k <= 0;
                        l <= 0;
                        m <= 0;
                        n <= 0;
                    end
                end
                FIND_BEST: begin
                    if (domino_count < K) begin
                        if (i < 48) begin
                            if (j < 48) begin
                                if (k < 48) begin
                                    if (l < 48) begin
                                        if (m < 48) begin
                                            if (n < 48) begin
                                                // Check if dominoes are non-overlapping
                                                temp_mask <= 0;
                                                temp_covered <= 0;
                                                temp_mask <= temp_mask | (1 << domino_list[i][0]) | (1 << domino_list[i][1]);
                                                temp_covered <= temp_covered + domino_values[i];
                                                if (j != i) begin
                                                    temp_mask <= temp_mask | (1 << domino_list[j][0]) | (1 << domino_list[j][1]);
                                                    temp_covered <= temp_covered + domino_values[j];
                                                end
                                                if (k != i && k != j) begin
                                                    temp_mask <= temp_mask | (1 << domino_list[k][0]) | (1 << domino_list[k][1]);
                                                    temp_covered <= temp_covered + domino_values[k];
                                                end
                                                if (l != i && l != j && l != k) begin
                                                    temp_mask <= temp_mask | (1 << domino_list[l][0]) | (1 << domino_list[l][1]);
                                                    temp_covered <= temp_covered + domino_values[l];
                                                end
                                                if (m != i && m != j && m != k && m != l) begin
                                                    temp_mask <= temp_mask | (1 << domino_list[m][0]) | (1 << domino_list[m][1]);
                                                    temp_covered <= temp_covered + domino_values[m];
                                                end
                                                if (n != i && n != j && n != k && n != l && n != m) begin
                                                    temp_mask <= temp_mask | (1 << domino_list[n][0]) | (1 << domino_list[n][1]);
                                                    temp_covered <= temp_covered + domino_values[n];
                                                end
                                                // Check if all dominoes are non-overlapping
                                                if (temp_mask == (1 << domino_list[i][0]) | (1 << domino_list[i][1]) | (1 << domino_list[j][0]) | (1 << domino_list[j][1]) | (1 << domino_list[k][0]) | (1 << domino_list[k][1]) | (1 << domino_list[l][0]) | (1 << domino_list[l][1]) | (1 << domino_list[m][0]) | (1 << domino_list[m][1]) | (1 << domino_list[n][0]) | (1 << domino_list[n][1])) begin
                                                    if (temp_covered > best_covered) begin
                                                        best_covered <= temp_covered;
                                                    end
                                                end
                                                n <= n + 1;
                                            end else begin
                                                n <= 0;
                                                m <= m + 1;
                                            end
                                        end else begin
                                            m <= 0;
                                            l <= l + 1;
                                        end
                                    end else begin
                                        l <= 0;
                                        k <= k + 1;
                                    end
                                end else begin
                                    k <= 0;
                                    j <= j + 1;
                                end
                            end else begin
                                j <= 0;
                                i <= i + 1;
                            end
                        end else begin
                            i <= 0;
                            domino_count <= domino_count + 1;
                        end
                    end else begin
                        state <= DONE;
                        min_sum <= total_sum - best_covered;
                        done <= 1;
                    end
                end
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule