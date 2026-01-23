module route_division (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [9:0] x_arr [0:7],
    input [9:0] y_arr [0:7],
    output reg [10:0] result,
    output reg done
);

localparam [3:0] MAX_N = 8;
localparam [3:0] IDLE = 4'd0;
localparam [3:0] LOAD = 4'd1;
localparam [3:0] INIT = 4'd2;
localparam [3:0] CHECK_PART = 4'd3;
localparam [3:0] INIT_PAIRS = 4'd4;
localparam [3:0] GET_COORDS = 4'd5;
localparam [3:0] CALC_DIST = 4'd6;
localparam [3:0] UPDATE_DMAX = 4'd7;
localparam [3:0] NEXT_J = 4'd8;
localparam [3:0] NEXT_I = 4'd9;
localparam [3:0] UPDATE_BEST = 4'd10;
localparam [3:0] NEXT_PART = 4'd11;
localparam [3:0] OUTPUT = 4'd12;
localparam [3:0] FINISH = 4'd13;

reg [3:0] state;
reg [3:0] N_reg;
reg [10:0] best_result;
reg [MAX_N-1:0] partition;
reg [MAX_N-1:0] partition_max;
reg [2:0] i;
reg [2:0] j;
reg [10:0] max_diam;
reg [10:0] max_A;
reg [10:0] max_B;
reg [7:0] cycle_counter;

reg [9:0] x_i, x_j, y_i, y_j;
reg group_i, group_j;
reg [9:0] dx, dy;
reg [10:0] dist;
reg [10:0] new_max_A, new_max_B;

localparam [7:0] MAX_CYCLES = 8'd200;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 11'd0;
        N_reg <= 4'd0;
        best_result <= 11'h7FF;
        partition <= 8'd0;
        partition_max <= 8'd0;
        i <= 3'd0;
        j <= 3'd0;
        max_diam <= 11'd0;
        max_A <= 11'd0;
        max_B <= 11'd0;
        cycle_counter <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_counter <= 8'd0;
                if (start) begin
                    state <= LOAD;
                end
            end

            LOAD: begin
                N_reg <= N;
                state <= INIT;
            end

            INIT: begin
                best_result <= 11'h7FF;
                partition <= 8'd0;
                partition_max <= (8'hFF >> (8 - N_reg));
                state <= CHECK_PART;
            end

            CHECK_PART: begin
                if (partition <= partition_max) begin
                    i <= 3'd0;
                    state <= INIT_PAIRS;
                end else begin
                    state <= OUTPUT;
                end
            end

            INIT_PAIRS: begin
                j <= i + 3'd1;
                max_A <= 11'd0;
                max_B <= 11'd0;
                state <= (N_reg < 3'd2) ? NEXT_I : GET_COORDS;
            end

            GET_COORDS: begin
                x_i <= x_arr[i];
                x_j <= x_arr[j];
                y_i <= y_arr[i];
                y_j <= y_arr[j];
                group_i <= partition[i];
                group_j <= partition[j];
                state <= CALC_DIST;
            end

            CALC_DIST: begin
                dx <= (x_i > x_j) ? (x_i - x_j) : (x_j - x_i);
                dy <= (y_i > y_j) ? (y_i - y_j) : (y_j - y_i);
                state <= UPDATE_DMAX;
            end

            UPDATE_DMAX: begin
                dist <= dx + dy;
                if (group_i == 1'b0 && group_j == 1'b0) begin
                    if (dist > max_A) max_A <= dist;
                end
                if (group_i == 1'b1 && group_j == 1'b1) begin
                    if (dist > max_B) max_B <= dist;
                end
                state <= NEXT_J;
            end

            NEXT_J: begin
                if (j < N_reg - 1) begin
                    j <= j + 3'd1;
                    state <= GET_COORDS;
                end else begin
                    state <= NEXT_I;
                end
            end

            NEXT_I: begin
                if (i < N_reg - 2) begin
                    i <= i + 3'd1;
                    state <= INIT_PAIRS;
                end else begin
                    max_diam <= (max_A > max_B) ? max_A : max_B;
                    state <= UPDATE_BEST;
                end
            end

            UPDATE_BEST: begin
                if (max_diam < best_result) begin
                    best_result <= max_diam;
                end
                state <= NEXT_PART;
            end

            NEXT_PART: begin
                cycle_counter <= cycle_counter + 8'd1;
                if (partition < partition_max) begin
                    partition <= partition + 8'd1;
                    state <= CHECK_PART;
                end else begin
                    state <= OUTPUT;
                end
            end

            OUTPUT: begin
                if (N_reg > 4'd1) begin
                    result <= best_result;
                end else begin
                    result <= 11'd0;
                end
                state <= FINISH;
            end

            FINISH: begin
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