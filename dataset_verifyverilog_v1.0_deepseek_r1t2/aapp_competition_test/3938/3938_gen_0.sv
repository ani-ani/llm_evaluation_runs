module min_cost_cover #(
    parameter MAX_ROWS = 16,
    parameter MAX_COLS = 16,
    parameter DATA_WIDTH = 16,
    parameter RESULT_WIDTH = 32
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] r_cnt,
    input wire [4:0] c_cnt,
    input wire [DATA_WIDTH-1:0] row_cost [0:MAX_ROWS-1],
    input wire [DATA_WIDTH-1:0] col_cost [0:MAX_COLS-1],
    input wire [MAX_ROWS-1:0] col_row_mask [0:MAX_COLS-1],
    output reg [RESULT_WIDTH-1:0] min_cost,
    output reg done
);
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOOP = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [MAX_ROWS-1:0] row_mask;
    wire [MAX_ROWS:0] limit;
    assign limit = (1 << r_cnt);

    reg [RESULT_WIDTH-1:0] sum_rows_comb;
    reg [RESULT_WIDTH-1:0] sum_cols_comb;
    wire [RESULT_WIDTH-1:0] total_comb;

    integer i, j;

    // Sum rows comb logic
    always @(*) begin
        sum_rows_comb = {RESULT_WIDTH{1'b0}};
        for (i = 0; i < MAX_ROWS; i = i + 1) begin
            if (i < r_cnt && row_mask[i]) begin
                sum_rows_comb = sum_rows_comb + row_cost[i];
            end
        end
    end

    // Sum cols comb logic
    always @(*) begin
        sum_cols_comb = {RESULT_WIDTH{1'b0}};
        for (j = 0; j < MAX_COLS; j = j + 1) begin
            if (j < c_cnt && (col_row_mask[j] & ~row_mask) != 0) begin
                sum_cols_comb = sum_cols_comb + col_cost[j];
            end
        end
    end

    assign total_comb = sum_rows_comb + sum_cols_comb;

    // FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            row_mask <= {MAX_ROWS{1'b0}};
            min_cost <= {RESULT_WIDTH{1'b1}};
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        row_mask <= {MAX_ROWS{1'b0}};
                        min_cost <= {RESULT_WIDTH{1'b1}};
                        state <= LOOP;
                    end
                end

                LOOP: begin
                    if (row_mask < limit) begin
                        if (total_comb < min_cost) begin
                            min_cost <= total_comb;
                        end
                        row_mask <= row_mask + 1;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule