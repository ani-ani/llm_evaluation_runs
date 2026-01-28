module permutation_sorter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [399:0] table_data,
    input wire [3:0] n,
    input wire [3:0] m,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_NO_SWAP = 3'd1;
    localparam [2:0] GENERATE_COLUMN_SWAP = 3'd2;
    localparam [2:0] APPLY_SWAP = 3'd3;
    localparam [2:0] CHECK_ROW = 3'd4;
    localparam [2:0] UPDATE_RESULT = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    // Internal registers
    reg [2:0] state;
    reg [4:0] row_idx;
    reg [4:0] col_idx;
    reg [4:0] c1;
    reg [4:0] c2;
    reg [4:0] mismatch_count;
    reg [3:0] m_reg;
    reg [3:0] n_reg;
    reg found_valid;
    reg [7:0] temp_row [0:19];  // Temporary buffer for current row
    reg [7:0] table_reg [0:399];  // Storage for input table
    reg [19:0] valid_mask;  // Track valid column swaps
    reg [4:0] max_mismatches;

    // Helper signals
    wire [7:0] expected_val;
    wire [7:0] compare_val;
    wire mismatch;

    // Combinational logic for value lookup
    assign expected_val = col_idx + 8'd1;
    assign compare_val = (col_idx == c1) ? table_reg[row_idx * 20 + c2] :
                         (col_idx == c2) ? table_reg[row_idx * 20 + c1] :
                         table_reg[row_idx * 20 + col_idx];
    assign mismatch = (compare_val != expected_val);

    // Max mismatches per row (2 or less for valid permutation)
    always @(*) begin
        if (m_reg <= 8'd2) begin
            max_mismatches = 5'd2;
        end else begin
            max_mismatches = 5'd2;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            row_idx <= 5'd0;
            col_idx <= 5'd0;
            c1 <= 5'd0;
            c2 <= 5'd0;
            mismatch_count <= 5'd0;
            m_reg <= 4'd0;
            n_reg <= 4'd0;
            found_valid <= 1'b0;
            valid_mask <= 20'hFFFFF;
            // Initialize table_reg
            for (integer i = 0; i < 400; i = i + 1) begin
                table_reg[i] <= 8'd0;
            end
            // Initialize temp_row
            for (integer i = 0; i < 20; i = i + 1) begin
                temp_row[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    found_valid <= 1'b0;
                    valid_mask <= 20'hFFFFF;
                    if (start) begin
                        m_reg <= m;
                        n_reg <= n;
                        // Store input table
                        for (integer i = 0; i < 400; i = i + 1) begin
                            table_reg[i] <= table_data[i*8 +: 8];
                        end
                        row_idx <= 5'd0;
                        col_idx <= 5'd0;
                        c1 <= 5'd0;
                        c2 <= 5'd0;
                        state <= CHECK_NO_SWAP;
                    end
                end

                CHECK_NO_SWAP: begin
                    // Check with no column swap (c1=c2=0, meaning no swap)
                    c1 <= 5'd0;
                    c2 <= 5'd0;
                    row_idx <= 5'd0;
                    mismatch_count <= 5'd0;
                    state <= CHECK_ROW;
                end

                CHECK_ROW: begin
                    if (col_idx < m_reg) begin
                        // Compare current column with expected value
                        if (mismatch) begin
                            mismatch_count <= mismatch_count + 5'd1;
                        end
                        col_idx <= col_idx + 5'd1;
                    end else begin
                        // Finished row
                        col_idx <= 5'd0;
                        if (mismatch_count <= max_mismatches) begin
                            // Row is valid for this column swap
                            row_idx <= row_idx + 5'd1;
                            if (row_idx + 5'd1 >= n_reg) begin
                                // All rows valid
                                found_valid <= 1'b1;
                                state <= UPDATE_RESULT;
                            end else begin
                                // Continue to next row
                                mismatch_count <= 5'd0;
                            end
                        end else begin
                            // Row invalid, try next column swap
                            if (c1 == c2 && c1 == 5'd0) begin
                                // No-swap case failed
                                state <= GENERATE_COLUMN_SWAP;
                                c1 <= 5'd1;
                                c2 <= 5'd1;
                            end else begin
                                // Generate next column swap
                                state <= GENERATE_COLUMN_SWAP;
                            end
                        end
                    end
                end

                GENERATE_COLUMN_SWAP: begin
                    if (c1 < m_reg) begin
                        if (c2 < m_reg - 5'd1) begin
                            c2 <= c2 + 5'd1;
                        end else begin
                            c1 <= c1 + 5'd1;
                            c2 <= c1 + 5'd1;
                        end
                        // Skip invalid swaps (already tested or marked invalid)
                        if (c1 == 5'd0 && c2 == 5'd0) begin
                            // Already tested
                            if (c1 < m_reg - 5'd1) begin
                                c1 <= 5'd1;
                                c2 <= 5'd1;
                            end else begin
                                state <= DONE_STATE;
                            end
                        end else if (c1 >= m_reg || c2 >= m_reg) begin
                            state <= DONE_STATE;
                        end else begin
                            // Check if this swap is valid
                            row_idx <= 5'd0;
                            mismatch_count <= 5'd0;
                            state <= CHECK_ROW;
                        end
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                UPDATE_RESULT: begin
                    result <= 1'b1;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    if (!found_valid && (c1 >= m_reg || (c1 == m_reg - 5'd1 && c2 >= m_reg))) begin
                        result <= 1'b0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule