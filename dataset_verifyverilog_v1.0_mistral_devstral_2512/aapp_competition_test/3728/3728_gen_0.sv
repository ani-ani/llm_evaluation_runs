module table_sort_check #(
    parameter N = 4,
    parameter M = 4,
    parameter DATA_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [(N*M*DATA_WIDTH)-1:0] table_in,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] UNPACK = 3'd1;
    localparam [2:0] CHECK_COL_SWAP = 3'd2;
    localparam [2:0] CHECK_ROWS = 3'd3;
    localparam [2:0] COMPUTE_RESULT = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Table storage
    reg [DATA_WIDTH-1:0] table [0:N-1][0:M-1];
    reg [DATA_WIDTH-1:0] target [0:N-1][0:M-1];

    // Counters for iteration
    reg [1:0] col_swap_i, col_swap_j;
    reg [1:0] row_i;
    reg [1:0] col_i;

    // Check results
    reg row_fixable [0:N-1];
    reg all_rows_fixable;
    reg found_valid_swap;

    // Initialize target table (identity)
    integer i, j;
    initial begin
        for (i = 0; i < N; i = i + 1) begin
            for (j = 0; j < M; j = j + 1) begin
                target[i][j] = j + 1;
            end
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            found_valid_swap <= 1'b0;
            col_swap_i <= 2'd0;
            col_swap_j <= 2'd0;
            row_i <= 2'd0;
            col_i <= 2'd0;
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < M; j = j + 1) begin
                    table[i][j] <= {DATA_WIDTH{1'b0}};
                end
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= UNPACK;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                UNPACK: begin
                    // Unpack table_in into table
                    for (i = 0; i < N; i = i + 1) begin
                        for (j = 0; j < M; j = j + 1) begin
                            table[i][j] <= table_in[(i*M + j)*DATA_WIDTH +: DATA_WIDTH];
                        end
                    end
                    next_state <= CHECK_COL_SWAP;
                end

                CHECK_COL_SWAP: begin
                    // Check if current column swap works
                    if (col_swap_i == M) begin
                        // All column swaps checked
                        if (found_valid_swap) begin
                            next_state <= COMPUTE_RESULT;
                        end else begin
                            next_state <= FINISH;
                        end
                    end else if (col_swap_j == M) begin
                        // Move to next i
                        col_swap_i <= col_swap_i + 1'b1;
                        col_swap_j <= col_swap_i + 1'b1;
                        row_i <= 2'd0;
                    end else begin
                        // Check this column swap
                        next_state <= CHECK_ROWS;
                    end
                end

                CHECK_ROWS: begin
                    // Check if all rows are fixable with current column swap
                    if (row_i == N) begin
                        // All rows checked for this swap
                        if (all_rows_fixable) begin
                            found_valid_swap <= 1'b1;
                        end
                        col_swap_j <= col_swap_j + 1'b1;
                        row_i <= 2'd0;
                        next_state <= CHECK_COL_SWAP;
                    end else begin
                        // Check current row
                        next_state <= CHECK_ROWS;
                        row_i <= row_i + 1'b1;
                    end
                end

                COMPUTE_RESULT: begin
                    result <= found_valid_swap;
                    next_state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase

            // Cycle counter
            if (state != IDLE && state != FINISH) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state <= FINISH;
                end
            end
        end
    end

    // Helper logic to check if a row is fixable
    always @(*) begin
        reg [1:0] mismatch_count = 2'd0;
        reg [DATA_WIDTH-1:0] temp_row [0:M-1];
        reg [DATA_WIDTH-1:0] swapped_col [0:M-1];

        // Apply column swap
        for (j = 0; j < M; j = j + 1) begin
            if (j == col_swap_i) begin
                swapped_col[j] = table[row_i][col_swap_j];
            end else if (j == col_swap_j) begin
                swapped_col[j] = table[row_i][col_swap_i];
            end else begin
                swapped_col[j] = table[row_i][j];
            end
        end

        // Count mismatches
        for (j = 0; j < M; j = j + 1) begin
            if (swapped_col[j] != target[row_i][j]) begin
                mismatch_count = mismatch_count + 1'b1;
            end
        end

        // Row is fixable if 0 or 2 mismatches
        row_fixable[row_i] = (mismatch_count == 2'd0 || mismatch_count == 2'd2);

        // Check if all rows are fixable
        all_rows_fixable = 1'b1;
        for (i = 0; i < N; i = i + 1) begin
            all_rows_fixable = all_rows_fixable && row_fixable[i];
        end
    end

endmodule