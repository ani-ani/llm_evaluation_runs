module laser_maximizer (
    input clk,
    input rst_n,
    input start,
    input [7:0] y_left [0:15],
    input [7:0] y_right [0:15],
    input [3:0] n_left,
    input [3:0] n_right,
    output reg [7:0] result,
    output reg done
);

localparam IDLE = 3'd0;
localparam PREPARE_SOURCES = 3'd1;
localparam PROCESS_PAIRS = 3'd2;
localparam CALCULATE_MAX = 3'd3;
localparam DONE = 3'd4;

reg [2:0] state;
reg [7:0] left_y [0:15];
reg [7:0] right_y [0:15];
reg [3:0] n_left_reg, n_right_reg;
reg [3:0] i_cnt, j_cnt;
reg [8:0] current_sum;
reg [7:0] pair_idx;
reg [7:0] total_pairs;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        left_y <= 0;
        right_y <= 0;
        n_left_reg <= 0;
        n_right_reg <= 0;
        i_cnt <= 0;
        j_cnt <= 0;
        pair_idx <= 0;
        total_pairs <= 0;
        result <= 0;
        done <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= PREPARE_SOURCES;
                else state <= IDLE;
            end
            PREPARE_SOURCES: begin
                left_y <= y_left;
                right_y <= y_right;
                n_left_reg <= n_left;
                n_right_reg <= n_right;
                state <= PROCESS_PAIRS;
            end
            PROCESS_PAIRS: begin
                if (i_cnt < n_left_reg) begin
                    if (j_cnt < n_right_reg) begin
                        current_sum = left_y[i_cnt] + right_y[j_cnt];
                        pair_idx <= pair_idx + 1;
                        j_cnt <= j_cnt + 1;
                    end else begin
                        j_cnt <= 0;
                        i_cnt <= i_cnt + 1;
                    end
                end else begin
                    state <= CALCULATE_MAX;
                    total_pairs <= pair_idx;
                end
            end
            CALCULATE_MAX: begin
                result <= min(total_pairs, 32'd32);
                done <= 1;
                state <= CALCULATE_MAX;
            end
            DONE: state <= DONE;
        endcase
    end
end

endmodule