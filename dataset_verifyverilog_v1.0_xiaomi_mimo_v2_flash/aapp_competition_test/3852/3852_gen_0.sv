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

reg [2:0] state;
reg [DATA_WIDTH-1:0] array_reg [0:MAX_N-1];
reg [DATA_WIDTH-1:0] max_val, min_val;
reg [INDEX_WIDTH-1:0] max_index, min_index;
reg [6:0] neg_count, pos_count;
reg [6:0] total_count;
reg [1:0] strategy;
reg [INDEX_WIDTH-1:0] i;
reg [INDEX_WIDTH-1:0] j;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        count_valid <= 1'b0;
        op_valid <= 1'b0;
        done <= 1'b0;
        i <= 6'd0;
        j <= 6'd0;
        count <= 8'd0;
        max_val <= {DATA_WIDTH{1'b0}};
        min_val <= {DATA_WIDTH{1'b0}};
        max_index <= 6'd0;
        min_index <= 6'd0;
        neg_count <= 7'd0;
        pos_count <= 7'd0;
        total_count <= 7'd0;
        strategy <= 2'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                count_valid <= 1'b0;
                op_valid <= 1'b0;
                i <= 6'd0;
                j <= 6'd0;
                if (start) begin
                    state <= FIND_MAX_MIN;
                    for (integer k = 0; k < MAX_N; k = k + 1) begin
                        array_reg[k] <= array_in[DATA_WIDTH*k +: DATA_WIDTH];
                    end
                    max_val <= array_in[0 +: DATA_WIDTH];
                    min_val <= array_in[0 +: DATA_WIDTH];
                    max_index <= 6'd0;
                    min_index <= 6'd0;
                    neg_count <= 7'd0;
                    pos_count <= 7'd0;
                    if (array_in[0 +: DATA_WIDTH] < 0) begin
                        neg_count <= 7'd1;
                    end else if (array_in[0 +: DATA_WIDTH] > 0) begin
                        pos_count <= 7'd1;
                    end
                end
            end

            FIND_MAX_MIN: begin
                if (i < N) begin
                    if (i > 0) begin
                        if (array_reg[i] > max_val) begin
                            max_val <= array_reg[i];
                            max_index <= i;
                        end
                        if (array_reg[i] < min_val) begin
                            min_val <= array_reg[i];
                            min_index <= i;
                        end
                        if (array_reg[i] < 0) begin
                            neg_count <= neg_count + 7'd1;
                        end else if (array_reg[i] > 0) begin
                            pos_count <= pos_count + 7'd1;
                        end
                    end
                    i <= i + 6'd1;
                end else begin
                    state <= DECIDE;
                    i <= 6'd0;
                end
            end

            DECIDE: begin
                if (min_val >= 0) begin
                    strategy <= 2'd0;
                    total_count <= N - 7'd1;
                end else if (max_val <= 0) begin
                    strategy <= 2'd1;
                    total_count <= N - 7'd1;
                end else if (max_val >= -min_val) begin
                    strategy <= 2'd2;
                    total_count <= neg_count + (N - 7'd1);
                end else begin
                    strategy <= 2'd3;
                    total_count <= pos_count + (N - 7'd1);
                end
                state <= OUTPUT_COUNT;
            end

            OUTPUT_COUNT: begin
                count_valid <= 1'b1;
                count <= total_count[7:0];
                case (strategy)
                    2'd0: state <= PREFIX;
                    2'd1: state <= SUFFIX;
                    2'd2, 2'd3: state <= FIX;
                    default: state <= DONE_STATE;
                endcase
            end

            FIX: begin
                count_valid <= 1'b0;
                if (i < N) begin
                    if (((strategy == 2'd2) && (array_reg[i] < 0)) || 
                        ((strategy == 2'd3) && (array_reg[i] > 0))) begin
                        op_valid <= 1'b1;
                        if (strategy == 2'd2) begin
                            op_x <= max_index + 6'd1;
                            op_y <= i + 6'd1;
                        end else begin
                            op_x <= min_index + 6'd1;
                            op_y <= i + 6'd1;
                        end
                    end else begin
                        op_valid <= 1'b0;
                    end
                    i <= i + 6'd1;
                end else begin
                    op_valid <= 1'b0;
                    i <= 6'd0;
                    if (strategy == 2'd2) begin
                        state <= PREFIX;
                    end else begin
                        state <= SUFFIX;
                    end
                end
            end

            PREFIX: begin
                if (i < N - 6'd1) begin
                    op_valid <= 1'b1;
                    op_x <= i + 6'd1;
                    op_y <= i + 6'd2;
                    i <= i + 6'd1;
                end else begin
                    op_valid <= 1'b0;
                    state <= DONE_STATE;
                end
            end

            SUFFIX: begin
                if (i < N - 6'd1) begin
                    op_valid <= 1'b1;
                    op_x <= (N - 6'd1 - i) + 6'd1;
                    op_y <= (N - 6'd1 - i);
                    i <= i + 6'd1;
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