module purification_sol (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] grid,
    input wire [3:0] n,
    output reg [3:0] out_row,
    output reg [3:0] out_col,
    output reg out_valid,
    output reg done,
    output reg impossible
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK_ROWS = 3'd1;
    localparam [2:0] CHECK_COLS = 3'd2;
    localparam [2:0] OUTPUT_ROWS = 3'd3;
    localparam [2:0] OUTPUT_COLS = 3'd4;
    localparam [2:0] IMPOSSIBLE = 3'd5;
    localparam [2:0] DONE      = 3'd6;

    reg [2:0] state, next_state;
    reg [3:0] row_counter;
    reg [3:0] col_counter;
    reg [3:0] output_counter;
    reg [7:0] row_safe [0:7];
    reg [7:0] col_safe [0:7];
    reg [3:0] row_safe_count [0:7];
    reg [3:0] col_safe_count [0:7];
    reg rows_all_unsafe;
    reg cols_all_unsafe;
    reg [3:0] current_row;
    reg [3:0] current_col;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            row_counter <= 4'd0;
            col_counter <= 4'd0;
            output_counter <= 4'd0;
            rows_all_unsafe <= 1'b0;
            cols_all_unsafe <= 1'b0;
            current_row <= 4'd0;
            current_col <= 4'd0;
            out_row <= 4'd0;
            out_col <= 4'd0;
            out_valid <= 1'b0;
            done <= 1'b0;
            impossible <= 1'b0;

            for (i = 0; i < 8; i = i + 1) begin
                row_safe[i] <= 8'd0;
                col_safe[i] <= 8'd0;
                row_safe_count[i] <= 4'd0;
                col_safe_count[i] <= 4'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    out_valid <= 1'b0;
                    done <= 1'b0;
                    impossible <= 1'b0;
                    if (start) begin
                        next_state <= CHECK_ROWS;
                        row_counter <= 4'd0;
                        rows_all_unsafe <= 1'b0;
                        cols_all_unsafe <= 1'b0;
                    end
                end

                CHECK_ROWS: begin
                    if (row_counter < n) begin
                        row_safe[row_counter] <= 8'd0;
                        row_safe_count[row_counter] <= 4'd0;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < n && !grid[row_counter * 8 + i]) begin
                                row_safe[row_counter][i] <= 1'b1;
                                row_safe_count[row_counter] <= row_safe_count[row_counter] + 4'd1;
                            end
                        end

                        if (row_safe_count[row_counter] == 4'd0) begin
                            rows_all_unsafe <= 1'b1;
                        end

                        row_counter <= row_counter + 4'd1;
                        if (row_counter == n) begin
                            row_counter <= 4'd0;
                            next_state <= CHECK_COLS;
                        end
                    end
                end

                CHECK_COLS: begin
                    if (col_counter < n) begin
                        col_safe[col_counter] <= 8'd0;
                        col_safe_count[col_counter] <= 4'd0;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < n && !grid[i * 8 + col_counter]) begin
                                col_safe[col_counter][i] <= 1'b1;
                                col_safe_count[col_counter] <= col_safe_count[col_counter] + 4'd1;
                            end
                        end

                        if (col_safe_count[col_counter] == 4'd0) begin
                            cols_all_unsafe <= 1'b1;
                        end

                        col_counter <= col_counter + 4'd1;
                        if (col_counter == n) begin
                            col_counter <= 4'd0;
                            if (rows_all_unsafe && cols_all_unsafe) begin
                                next_state <= IMPOSSIBLE;
                            end else if (!rows_all_unsafe) begin
                                next_state <= OUTPUT_ROWS;
                                current_row <= 4'd0;
                            end else begin
                                next_state <= OUTPUT_COLS;
                                current_col <= 4'd0;
                            end
                        end
                    end
                end

                OUTPUT_ROWS: begin
                    if (output_counter < n) begin
                        out_row <= current_row;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < n && row_safe[current_row][i]) begin
                                out_col <= i;
                                break;
                            end
                        end
                        out_valid <= 1'b1;
                        output_counter <= output_counter + 4'd1;
                        current_row <= current_row + 4'd1;
                        if (output_counter == n) begin
                            next_state <= DONE;
                        end
                    end
                end

                OUTPUT_COLS: begin
                    if (output_counter < n) begin
                        out_col <= current_col;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < n && col_safe[current_col][i]) begin
                                out_row <= i;
                                break;
                            end
                        end
                        out_valid <= 1'b1;
                        output_counter <= output_counter + 4'd1;
                        current_col <= current_col + 4'd1;
                        if (output_counter == n) begin
                            next_state <= DONE;
                        end
                    end
                end

                IMPOSSIBLE: begin
                    impossible <= 1'b1;
                    next_state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule