module toll_optimizer (
input clk,
input rst_n,
input start,
input [15:0] entrance_0, entrance_1, entrance_2, entrance_3, entrance_4, entrance_5, entrance_6, entrance_7,
input [15:0] exit_0, exit_1, exit_2, exit_3, exit_4, exit_5, exit_6, exit_7,
output reg [31:0] min_toll_sum,
output reg done
);

localparam IDLE = 3'd0;
localparam LOAD_PERMUTATION = 3'd1;
localparam CHECK_FIXED_POINTS = 3'd2;
localparam COMPUTE_COST = 3'd3;
localparam UPDATE_MIN = 3'd4;
localparam NEXT_PERMUTATION = 3'd5;
localparam DONE = 3'd6;

reg [15:0] entrance_reg [7:0];
reg [15:0] exit_reg [7:0];
reg [31:0] min_sum;
reg [31:0] current_sum;
reg [7:0] current_perm [7:0];
reg [15:0] counter;
reg [2:0] state;
reg valid_perm;

always @(posedge clk) begin
    if (!rst_n) begin
        entrance_reg <= 0;
        exit_reg <= 0;
        min_sum <= 0;
        current_sum <= 0;
        counter <= 0;
        state <= IDLE;
        done <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= LOAD_PERMUTATION;
            end
            LOAD_PERMUTATION: begin
                entrance_reg[0] <= entrance_0;
                entrance_reg[1] <= entrance_1;
                entrance_reg[2] <= entrance_2;
                entrance_reg[3] <= entrance_3;
                entrance_reg[4] <= entrance_4;
                entrance_reg[5] <= entrance_5;
                entrance_reg[6] <= entrance_6;
                entrance_reg[7] <= entrance_7;
                exit_reg[0] <= exit_0;
                exit_reg[1] <= exit_1;
                exit_reg[2] <= exit_2;
                exit_reg[3] <= exit_3;
                exit_reg[4] <= exit_4;
                exit_reg[5] <= exit_5;
                exit_reg[6] <= exit_6;
                exit_reg[7] <= exit_7;
                state <= NEXT_PERMUTATION;
            end
            NEXT_PERMUTATION: begin
                if (counter < 40320) begin
                    current_perm <= counter[7:0];
                    counter <= counter + 1;
                    state <= CHECK_FIXED_POINTS;
                end else begin
                    state <= DONE;
                    done <= 1;
                end
            end
            CHECK_FIXED_POINTS: begin
                valid_perm = 1'b1;
                if (current_perm[0] == 0) valid_perm = 1'b0;
                if (current_perm[1] == 1) valid_perm = 1'b0;
                if (current_perm[2] == 2) valid_perm = 1'b0;
                if (current_perm[3] == 3) valid_perm = 1'b0;
                if (current_perm[4] == 4) valid_perm = 1'b0;
                if (current_perm[5] == 5) valid_perm = 1'b0;
                if (current_perm[6] == 6) valid_perm = 1'b0;
                if (current_perm[7] == 7) valid_perm = 1'b0;
                if (valid_perm) begin
                    state <= COMPUTE_COST;
                end else begin
                    state <= NEXT_PERMUTATION;
                end
            end
            COMPUTE_COST: begin
                current_sum <= (entrance_reg[0] > exit_reg[current_perm[0]] ? entrance_reg[0] - exit_reg[current_perm[0]] : exit_reg[current_perm[0]] - entrance_reg[0]) + (entrance_reg[1] > exit_reg[current_perm[1]] ? entrance_reg[1] - exit_reg[current_perm[1]] : exit_reg[current_perm[1]] - entrance_reg[1]) + (entrance_reg[2] > exit_reg[current_perm[2]] ? entrance_reg[2] - exit_reg[current_perm[2]] : exit_reg[current_perm[2]] - entrance_reg[2]) + (entrance_reg[3] > exit_reg[current_perm[3]] ? entrance_reg[3] - exit_reg[current_perm[3]] : exit_reg[current_perm[3]] - entrance_reg[3]) + (entrance_reg[4] > exit_reg[current_perm[4]] ? entrance_reg[4] - exit_reg[current_perm[4]] : exit_reg[current_perm[4]] - entrance_reg[4]) + (entrance_reg[5] > exit_reg[current_perm[5]] ? entrance_reg[5] - exit_reg[current_perm[5]] : exit_reg[current_perm[5]] - entrance_reg[5]) + (entrance_reg[6] > exit_reg[current_perm[6]] ? entrance_reg[6] - exit_reg[current_perm[6]] : exit_reg[current_perm[6]] - entrance_reg[6]) + (entrance_reg[7] > exit_reg[current_perm[7]] ? entrance_reg[7] - exit_reg[current_perm[7]] : exit_reg[current_perm[7]] - entrance_reg[7]);
                state <= UPDATE_MIN;
            end
            UPDATE_MIN: begin
                if (min_sum == 0 || current_sum < min_sum) begin
                    min_sum <= current_sum;
                end
                state <= NEXT_PERMUTATION;
            end
            DONE: begin
            end
        endcase
    end
endmodule