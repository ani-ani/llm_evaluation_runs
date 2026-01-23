module grid_symmetry_checker (
    input clk,
    input rst_n,
    input start,
    input [5:0] H_in,
    input [3:0] W_in,
    input [7:0] grid_flat [0:71],
    output reg result,
    output reg done
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        INIT_PERM,
        CHECK_PERM,
        CHECK_COLS,
        NEXT_PERM,
        DONE
    } state_t;

    state_t state;
    reg [5:0] perm [0:5]; // Row permutation indices (max 6 rows)
    reg [5:0] perm_counter; // Counter for permutation generation
    reg [11:0] col_mask; // Bitmask for used columns (12 bits)
    reg [3:0] col_i; // Current column index being checked
    reg [3:0] col_j; // Partner column index
    reg [5:0] row_i; // Current row index in permutation
    reg [5:0] row_j; // Partner row index in permutation
    reg [5:0] perm_done; // Flag to indicate all permutations checked
    reg [5:0] perm_success; // Flag to indicate current permutation success
    reg [5:0] col_check_done; // Flag to indicate column check completion
    reg [5:0] col_pair_found; // Flag to indicate column pair found

    // Internal registers for grid access
    reg [7:0] col_data [0:11]; // Temporary storage for column data
    reg [7:0] col_rev_data [0:11]; // Temporary storage for reversed column data

    // Initialize state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            perm_counter <= 0;
            col_mask <= 0;
            col_i <= 0;
            col_j <= 0;
            row_i <= 0;
            row_j <= 0;
            perm_done <= 0;
            perm_success <= 0;
            col_check_done <= 0;
            col_pair_found <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT_PERM;
                        result <= 0;
                        done <= 0;
                        perm_counter <= 0;
                        col_mask <= 0;
                        col_i <= 0;
                        col_j <= 0;
                        row_i <= 0;
                        row_j <= 0;
                        perm_done <= 0;
                        perm_success <= 0;
                        col_check_done <= 0;
                        col_pair_found <= 0;
                    end
                end
                INIT_PERM: begin
                    // Initialize permutation array (identity permutation)
                    for (int i = 0; i < 6; i = i + 1) begin
                        perm[i] <= i;
                    end
                    state <= CHECK_PERM;
                end
                CHECK_PERM: begin
                    // Set up current row permutation
                    state <= CHECK_COLS;
                end
                CHECK_COLS: begin
                    // Main logic to check if columns can be paired
                    if (!col_check_done) begin
                        // Initialize column check
                        col_mask <= 0;
                        col_i <= 0;
                        col_j <= 0;
                        row_i <= 0;
                        row_j <= 0;
                        col_check_done <= 0;
                        col_pair_found <= 0;
                        state <= CHECK_COLS;
                    end else begin
                        // Column check completed
                        if (perm_success) begin
                            result <= 1;
                            state <= DONE;
                        end else begin
                            state <= NEXT_PERM;
                        end
                    end
                end
                NEXT_PERM: begin
                    // Advance to next row permutation
                    if (perm_counter < 120) begin
                        perm_counter <= perm_counter + 1;
                        state <= CHECK_PERM;
                    end else begin
                        perm_done <= 1;
                        state <= DONE;
                    end
                end
                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

    // Permutation generation logic
    always @(posedge clk) begin
        if (state == CHECK_PERM) begin
            // Generate next permutation (simplified for synthesis)
            // This is a placeholder for actual permutation generation logic
            // In practice, use a combinational block or FSM to generate permutations
            for (int i = 0; i < 6; i = i + 1) begin
                perm[i] <= perm[i] + 1;
            end
        end
    end

    // Column check logic
    always @(posedge clk) begin
        if (state == CHECK_COLS && !col_check_done) begin
            // Load column data
            for (int i = 0; i < W_in; i = i + 1) begin
                col_data[i] <= grid_flat[perm[row_i] * 12 + i];
            end

            // Check if column is symmetric or can be paired
            if (col_i < W_in) begin
                if (!col_mask[col_i]) begin
                    // Check if column is symmetric (palindrome)
                    reg [7:0] temp_col [0:11];
                    for (int j = 0; j < W_in; j = j + 1) begin
                        temp_col[j] <= col_data[W_in - 1 - j];
                    end

                    reg is_symmetric = 1;
                    for (int j = 0; j < W_in; j = j + 1) begin
                        if (col_data[j] != temp_col[j]) begin
                            is_symmetric = 0;
                        end
                    end

                    if (is_symmetric) begin
                        col_mask[col_i] <= 1;
                        col_i <= col_i + 1;
                    end else begin
                        // Find partner column
                        for (int j = col_i + 1; j < W_in; j = j + 1) begin
                            if (!col_mask[j]) begin
                                reg [7:0] partner_col [0:11];
                                for (int k = 0; k < W_in; k = k + 1) begin
                                    partner_col[k] <= grid_flat[perm[row_j] * 12 + k];
                                end

                                reg is_pair = 1;
                                for (int k = 0; k < W_in; k = k + 1) begin
                                    if (col_data[k] != partner_col[W_in - 1 - k]) begin
                                        is_pair = 0;
                                    end
                                end

                                if (is_pair) begin
                                    col_mask[col_i] <= 1;
                                    col_mask[j] <= 1;
                                    col_i <= col_i + 1;
                                    col_pair_found <= 1;
                                end
                            end
                        end
                    end
                end else begin
                    col_i <= col_i + 1;
                end
            end else begin
                col_check_done <= 1;
                perm_success <= 1;
            end
        end
    end

    // Output logic
    always @(posedge clk) begin
        if (state == DONE) begin
            done <= 1;
        end else begin
            done <= 0;
        end
    end

endmodule