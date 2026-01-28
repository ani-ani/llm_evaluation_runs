module PermutationChecker(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [399:0] table_data,
    input wire [3:0] n,
    input wire [3:0] m,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_NO_SWAP = 3'd1;
    localparam [2:0] GENERATE_COLUMN_SWAP = 3'd2;
    localparam [2:0] CHECK_ROW = 3'd3;
    localparam [2:0] UPDATE_RESULT = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [4:0] row_idx;
    reg [4:0] col_idx;
    reg [4:0] c1, c2;
    reg [4:0] mismatch_count;
    reg [4:0] cycle_count;
    reg [3:0] max_rows;
    reg [3:0] max_cols;
    reg valid_found;

    // Constants
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State machine
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
            cycle_count <= 8'd0;
            max_rows <= 4'd0;
            max_cols <= 4'd0;
            valid_found <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_NO_SWAP;
                    max_rows = n;
                    max_cols = m;
                    row_idx = 5'd0;
                    col_idx = 5'd0;
                    c1 = 5'd0;
                    c2 = 5'd0;
                    mismatch_count = 5'd0;
                    cycle_count = 8'd0;
                    valid_found = 1'b0;
                end
            end

            CHECK_NO_SWAP: begin
                if (row_idx < max_rows) begin
                    if (col_idx < max_cols) begin
                        // Check current element
                        if (col_idx == 5'd0) mismatch_count = 5'd0;
                        if (table_data[row_idx * 20 + col_idx] != col_idx + 1) begin
                            mismatch_count = mismatch_count + 1;
                        end
                        col_idx = col_idx + 1;
                    end else begin
                        // Row complete
                        if (mismatch_count > 2) begin
                            next_state = GENERATE_COLUMN_SWAP;
                        end else begin
                            row_idx = row_idx + 1;
                            col_idx = 5'd0;
                        end
                    end
                end else begin
                    // All rows checked with no swap
                    valid_found = 1'b1;
                    next_state = DONE_STATE;
                end
            end

            GENERATE_COLUMN_SWAP: begin
                if (c1 < max_cols) begin
                    if (c2 < max_cols) begin
                        if (c2 >= c1) begin
                            next_state = CHECK_ROW;
                            row_idx = 5'd0;
                            col_idx = 5'd0;
                        end else begin
                            c2 = c2 + 1;
                        end
                    end else begin
                        c1 = c1 + 1;
                        c2 = 5'd0;
                    end
                end else begin
                    // No valid swap found
                    next_state = DONE_STATE;
                end
            end

            CHECK_ROW: begin
                if (row_idx < max_rows) begin
                    if (col_idx < max_cols) begin
                        // Check current element with swap
                        if (col_idx == 5'd0) mismatch_count = 5'd0;
                        if (col_idx == c1) begin
                            if (table_data[row_idx * 20 + c2] != col_idx + 1) begin
                                mismatch_count = mismatch_count + 1;
                            end
                        end else if (col_idx == c2) begin
                            if (table_data[row_idx * 20 + c1] != col_idx + 1) begin
                                mismatch_count = mismatch_count + 1;
                            end
                        end else begin
                            if (table_data[row_idx * 20 + col_idx] != col_idx + 1) begin
                                mismatch_count = mismatch_count + 1;
                            end
                        end
                        col_idx = col_idx + 1;
                    end else begin
                        // Row complete
                        if (mismatch_count > 2) begin
                            next_state = GENERATE_COLUMN_SWAP;
                        end else begin
                            row_idx = row_idx + 1;
                            col_idx = 5'd0;
                        end
                    end
                end else begin
                    // All rows checked with this swap
                    valid_found = 1'b1;
                    next_state = UPDATE_RESULT;
                end
            end

            UPDATE_RESULT: begin
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            if (state == DONE_STATE) begin
                result <= valid_found;
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

    // Cycle counter for safety
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else if (state != IDLE && state != DONE_STATE) begin
            if (cycle_count < MAX_CYCLES) begin
                cycle_count <= cycle_count + 1;
            end else begin
                // Force completion if max cycles reached
                next_state = DONE_STATE;
            end
        end
    end

endmodule