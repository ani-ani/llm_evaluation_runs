module hanoi_min_cost (
    input clk,
    input rst_n,
    input start,
    input [2:0] matrix_in [2:0],
    input [5:0] n,
    input [2:0] rod_index,
    input load_matrix,
    output reg [63:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        LOAD_MATRIX,
        PROCESSING,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Matrix storage
    reg [2:0] cost_matrix [2:0];
    reg [2:0] matrix_row_count;

    // DP tables
    reg [63:0] dp_current [2:0][2:0];
    reg [63:0] dp_next [2:0][2:0];

    // Processing counters
    reg [5:0] disk_count;
    reg [1:0] frm_count;
    reg [1:0] to_count;

    // Initialize DP table for 0 disks (base case)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            next_state <= IDLE;
            matrix_row_count <= 0;
            disk_count <= 0;
            frm_count <= 0;
            to_count <= 0;
            done <= 0;
            result <= 0;

            // Initialize cost matrix
            for (int i = 0; i < 3; i++) begin
                for (int j = 0; j < 3; j++) begin
                    cost_matrix[i][j] <= 0;
                end
            end

            // Initialize DP tables (dp[0][i][j] = 0 for all i,j)
            for (int i = 0; i < 3; i++) begin
                for (int j = 0; j < 3; j++) begin
                    dp_current[i][j] <= 0;
                    dp_next[i][j] <= 0;
                end
            end
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    if (start) begin
                        next_state <= LOAD_MATRIX;
                        matrix_row_count <= 0;
                    end
                end

                LOAD_MATRIX: begin
                    if (load_matrix) begin
                        // Load current row
                        for (int j = 0; j < 3; j++) begin
                            cost_matrix[rod_index][j] <= matrix_in[j];
                        end
                        matrix_row_count <= matrix_row_count + 1;

                        if (matrix_row_count == 2) begin
                            next_state <= PROCESSING;
                            disk_count <= 1;
                            frm_count <= 0;
                            to_count <= 0;
                        end
                    end
                end

                PROCESSING: begin
                    // Compute other rod
                    reg [1:0] other = 3 - frm_count - to_count;

                    // Compute both strategies
                    reg [63:0] strategy1 = dp_current[frm_count][other] + cost_matrix[frm_count][to_count] + dp_current[other][to_count];
                    reg [63:0] strategy2 = dp_current[frm_count][to_count] + cost_matrix[frm_count][other] + 
                                          dp_current[to_count][frm_count] + cost_matrix[other][to_count] + 
                                          dp_current[frm_count][to_count];

                    // Store minimum
                    dp_next[frm_count][to_count] <= (strategy1 < strategy2) ? strategy1 : strategy2;

                    // Update counters
                    if (to_count == 2) begin
                        if (frm_count == 2) begin
                            // Copy dp_next to dp_current for next disk
                            for (int i = 0; i < 3; i++) begin
                                for (int j = 0; j < 3; j++) begin
                                    dp_current[i][j] <= dp_next[i][j];
                                end
                            end

                            if (disk_count == n) begin
                                next_state <= DONE;
                                result <= dp_current[0][2];
                                done <= 1;
                            end else begin
                                disk_count <= disk_count + 1;
                            end
                            frm_count <= 0;
                            to_count <= 0;
                        end else begin
                            frm_count <= frm_count + 1;
                            to_count <= 0;
                        end
                    end else begin
                        to_count <= to_count + 1;
                    end
                end

                DONE: begin
                    if (!start) begin
                        next_state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule