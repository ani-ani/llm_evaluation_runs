module purification (
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

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_ROWS = 3'd1;
    localparam [2:0] DECIDE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] OUTPUT_NEXT = 3'd4;

    reg [2:0] state;
    reg [3:0] i, j;
    reg [15:0] row_has_dot;
    reg [15:0] col_has_dot;
    reg [3:0] row_dot_col [0:15];
    reg [3:0] col_dot_row [0:15];
    reg [1:0] mode;

    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            output_valid <= 1'b0;
            done <= 1'b0;
            no_solution <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            row_has_dot <= 16'd0;
            col_has_dot <= 16'd0;
            mode <= 2'd0;
            for (k = 0; k < 16; k = k + 1) begin
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
                        row_has_dot <= 16'd0;
                        col_has_dot <= 16'd0;
                        mode <= 2'd0;
                        for (k = 0; k < 16; k = k + 1) begin
                            row_dot_col[k] <= 4'd0;
                            col_dot_row[k] <= 4'd0;
                        end
                    end
                end

                CHECK_ROWS: begin
                    if (i < n) begin
                        if (j < n) begin
                            if (grid[i][j] == 1'b0) begin
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
                    if (&row_has_dot[0+:n]) begin
                        mode <= 2'd0;
                    end else if (&col_has_dot[0+:n]) begin
                        mode <= 2'd1;
                    end else begin
                        mode <= 2'd2;
                    end
                    i <= 4'd0;
                    state <= OUTPUT;
                end

                OUTPUT: begin
                    if (mode == 2'd0 || mode == 2'd1) begin
                        if (i < n) begin
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