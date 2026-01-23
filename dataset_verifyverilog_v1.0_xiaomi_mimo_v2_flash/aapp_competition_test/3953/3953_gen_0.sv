module grid_purification (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [15:0] grid [0:15],
    output reg output_valid,
    output reg [3:0] row_out,
    output reg [3:0] col_out,
    output reg done,
    output reg no_solution
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK_ROWS = 3'd1;
    localparam [2:0] DECIDE     = 3'd2;
    localparam [2:0] OUTPUT     = 3'd3;
    localparam [2:0] OUTPUT_NEXT = 3'd4;

    reg [2:0] state;
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] k;
    reg [15:0] row_has_dot;
    reg [15:0] col_has_dot;
    reg [3:0] row_dot_col [0:15];
    reg [3:0] col_dot_row [0:15];
    reg [1:0] mode;
    reg [3:0] n_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            output_valid <= 1'b0;
            done <= 1'b0;
            no_solution <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            row_has_dot <= 16'd0;
            col_has_dot <= 16'd0;
            mode <= 2'd0;
            n_reg <= 4'd0;
            row_out <= 4'd0;
            col_out <= 4'd0;
            for (k = 4'd0; k < 16; k = k + 1) begin
                row_dot_col[k] <= 4'd0;
                col_dot_row[k] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    output_valid <= 1'b0;
                    done <= 1'b0;
                    no_solution <= 1'b0;
                    if (start) begin
                        state <= CHECK_ROWS;
                        i <= 4'd0;
                        j <= 4'd0;
                        k <= 4'd0;
                        row_has_dot <= 16'd0;
                        col_has_dot <= 16'd0;
                        n_reg <= n;
                        for (k = 4'd0; k < 16; k = k + 1) begin
                            row_dot_col[k] <= 4'd0;
                            col_dot_row[k] <= 4'd0;
                        end
                    end
                end

                CHECK_ROWS: begin
                    if (i < n_reg) begin
                        if (j < n_reg) begin
                            if (grid[i][j] == 0) begin
                                if (!row_has_dot[i]) begin
                                    row_dot_col[i] <= j;
                                    row_has_dot[i] <= 1'b1;
                                end
                                if (!col_has_dot[j]) begin
                                    col_dot_row[j] <= i;
                                    col_has_dot[j] <= 1'b1;
                                end
                            end
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        state <= DECIDE;
                    end
                end

                DECIDE: begin
                    begin : check_rows_full
                        reg rows_full;
                        integer l;
                        rows_full = 1'b1;
                        for (l = 0; l < 16; l = l + 1) begin
                            if (l < n_reg) begin
                                if (!row_has_dot[l]) begin
                                    rows_full = 1'b0;
                                end
                            end
                        end
                        if (rows_full) begin
                            mode <= 2'd0;
                        end else begin
                            begin : check_cols_full
                                reg cols_full;
                                integer m;
                                cols_full = 1'b1;
                                for (m = 0; m < 16; m = m + 1) begin
                                    if (m < n_reg) begin
                                        if (!col_has_dot[m]) begin
                                            cols_full = 1'b0;
                                        end
                                    end
                                end
                                if (cols_full) begin
                                    mode <= 2'd1;
                                end else begin
                                    mode <= 2'd2;
                                end
                            end
                        end
                    end
                    i <= 4'd0;
                    state <= OUTPUT;
                end

                OUTPUT: begin
                    if (mode == 2'd0 || mode == 2'd1) begin
                        if (i < n_reg) begin
                            if (mode == 2'd0) begin
                                row_out <= i + 4'd1;
                                col_out <= row_dot_col[i] + 4'd1;
                            end else begin
                                row_out <= col_dot_row[i] + 4'd1;
                                col_out <= i + 4'd1;
                            end
                            output_valid <= 1'b1;
                            i <= i + 4'd1;
                            state <= OUTPUT_NEXT;
                        end else begin
                            done <= 1'b1;
                            state <= IDLE;
                        end
                    end else begin
                        no_solution <= 1'b1;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end

                OUTPUT_NEXT: begin
                    output_valid <= 1'b0;
                    state <= OUTPUT;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule