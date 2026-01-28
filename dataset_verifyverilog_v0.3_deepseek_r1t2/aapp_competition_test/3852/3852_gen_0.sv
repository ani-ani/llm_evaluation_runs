module non_decreasing_array #(
    parameter DATA_WIDTH = 24,
    parameter MAX_N = 50,
    parameter INDEX_WIDTH = 6
) (
    input clk,
    input rst_n,
    input start,
    input [5:0] N,
    input [DATA_WIDTH*MAX_N-1:0] array_in,
    output reg count_valid,
    output reg [7:0] count,
    output reg op_valid,
    output reg [INDEX_WIDTH-1:0] op_x,
    output reg [INDEX_WIDTH-1:0] op_y,
    output reg done
);

localparam [2:0] IDLE = 3'd0;
localparam [2:0] FIND_MAX_MIN = 3'd1;
localparam [2:0] DECIDE = 3'd2;
localparam [2:0] OUTPUT_COUNT = 3'd3;
localparam [2:0] FIX = 3'd4;
localparam [2:0] PREFIX = 3'd5;
localparam [2:0] SUFFIX = 3'd6;
localparam [2:0] DONE_STATE = 3'd7;

reg [2:0] state, next_state;
reg [DATA_WIDTH-1:0] array_reg [0:MAX_N-1];
reg [DATA_WIDTH-1:0] max_val, min_val;
reg [INDEX_WIDTH-1:0] max_index, min_index;
reg [6:0] neg_count, pos_count;
reg [6:0] total_count;
reg [1:0] strategy;
reg [INDEX_WIDTH:0] i;
integer j;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        count_valid <= 1'b0;
        op_valid <= 1'b0;
        done <= 1'b0;
        count <= 8'd0;
        i <= {INDEX_WIDTH+1{1'b0}};
        max_val <= {1'b0, {(DATA_WIDTH-1){1'b1}}};
        min_val <= {1'b1, {(DATA_WIDTH-1){1'b0}}};
        max_index <= {INDEX_WIDTH{1'b0}};
        min_index <= {INDEX_WIDTH{1'b0}};
        neg_count <= 7'd0;
        pos_count <= 7'd0;
        total_count <= 7'd0;
        strategy <= 2'd0;
        for (j = 0; j < MAX_N; j = j + 1) begin
            array_reg[j] <= {DATA_WIDTH{1'b0}};
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                count_valid <= 1'b0;
                op_valid <= 1'b0;
                if (start) begin
                    state <= FIND_MAX_MIN;
                    i <= {INDEX_WIDTH+1{1'b0}};
                    max_val <= {1'b0, {(DATA_WIDTH-1){1'b1}}};
                    min_val <= {1'b1, {(DATA_WIDTH-1){1'b0}}};
                    max_index <= {INDEX_WIDTH{1'b0}};
                    min_index <= {INDEX_WIDTH{1'b0}};
                    neg_count <= 7'd0;
                    pos_count <= 7'd0;
                end
            end

            FIND_MAX_MIN: begin
                if (i == {INDEX_WIDTH+1{1'b0}}) begin
                    for (j = 0; j < MAX_N; j = j + 1) begin
                        array_reg[j] <= array_in[DATA_WIDTH*j +: DATA_WIDTH];
                    end
                    if (N > 6'd0) begin
                        max_val <= array_in[0 +: DATA_WIDTH];
                        min_val <= array_in[0 +: DATA_WIDTH];
                        if (array_in[0 +: DATA_WIDTH][DATA_WIDTH-1]) neg_count <= 7'd1;
                        else if (|array_in[0 +: DATA_WIDTH]) pos_count <= 7'd1;
                    end
                    i <= 1;
                end else if (i < N) begin
                    if ($signed(array_reg[i]) > $signed(max_val)) begin
                        max_val <= array_reg[i];
                        max_index <= i;
                    end
                    if ($signed(array_reg[i]) < $signed(min_val)) begin
                        min_val <= array_reg[i];
                        min_index <= i;
                    end
                    if (array_reg[i][DATA_WIDTH-1]) neg_count <= neg_count + 7'd1;
                    else if (|array_reg[i]) pos_count <= pos_count + 7'd1;
                    i <= i + 1;
                end else begin
                    state <= DECIDE;
                    i <= {INDEX_WIDTH+1{1'b0}};
                end
            end

            DECIDE: begin
                if (min_val[DATA_WIDTH-1] == 1'b0) begin
                    strategy <= 2'd0;
                    total_count <= N - 1;
                end else if (max_val[DATA_WIDTH-1] == 1'b1) begin
                    strategy <= 2'd1;
                    total_count <= N - 1;
                end else if ($signed(max_val) >= -$signed(min_val)) begin
                    strategy <= 2'd2;
                    total_count <= neg_count + (N - 1);
                end else begin
                    strategy <= 2'd3;
                    total_count <= pos_count + (N - 1);
                end
                state <= OUTPUT_COUNT;
            end

            OUTPUT_COUNT: begin
                count_valid <= 1'b1;
                count <= total_count;
                case (strategy)
                    2'd0: state <= PREFIX;
                    2'd1: state <= SUFFIX;
                    2'd2, 2'd3: state <= FIX;
                    default: state <= PREFIX;
                endcase
            end

            FIX: begin
                count_valid <= 1'b0;
                if (i < N) begin
                    if (((strategy == 2'd2) && array_reg[i][DATA_WIDTH-1]) || 
                        ((strategy == 2'd3) && !array_reg[i][DATA_WIDTH-1] && (|array_reg[i]))) begin
                        op_valid <= 1'b1;
                        if (strategy == 2'd2) begin
                            op_x <= max_index + 1;
                            op_y <= i + 1;
                        end else begin
                            op_x <= min_index + 1;
                            op_y <= i + 1;
                        end
                    end else begin
                        op_valid <= 1'b0;
                    end
                    i <= i + 1;
                end else begin
                    op_valid <= 1'b0;
                    i <= {INDEX_WIDTH+1{1'b0}};
                    state <= (strategy == 2'd2) ? PREFIX : SUFFIX;
                end
            end

            PREFIX: begin
                if (i < (N - 1)) begin
                    op_valid <= 1'b1;
                    op_x <= i + 1;
                    op_y <= i + 2;
                    i <= i + 1;
                end else begin
                    op_valid <= 1'b0;
                    state <= DONE_STATE;
                end
            end

            SUFFIX: begin
                if (i < (N - 1)) begin
                    op_valid <= 1'b1;
                    op_x <= (N - 2 - i) + 1;
                    op_y <= (N - 1 - i);
                    i <= i + 1;
                end else begin
                    op_valid <= 1'b0;
                    state <= DONE_STATE;
                end
            end

            DONE_STATE: begin
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule