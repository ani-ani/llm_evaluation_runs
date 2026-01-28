module lava_game (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [3:0] start_idx,
    input wire [3:0] goal_idx,
    input wire [7:0] A,
    input wire [7:0] F,
    input wire [31:0] rows_data,
    input wire [31:0] cols_data,
    output reg [1:0] result,
    output reg done
);

localparam IDLE = 4'd0;
localparam BUILD_FATHER = 4'd1;
localparam FW_FATHER_K = 4'd2;
localparam FW_FATHER_I = 4'd3;
localparam FW_FATHER_J = 4'd4;
localparam SAVE_FATHER = 4'd5;
localparam BUILD_ELSA = 4'd6;
localparam FW_ELSA_K = 4'd7;
localparam FW_ELSA_I = 4'd8;
localparam FW_ELSA_J = 4'd9;
localparam COMPARE = 4'd10;
localparam DONE = 4'd11;

localparam SUCCESS = 2'b00;
localparam GO_FOR_IT = 2'b01;
localparam NO_CHANCE = 2'b10;
localparam NO_WAY = 2'b11;

reg [3:0] state, next_state;
reg [3:0] i_cnt, j_cnt, k_cnt;
reg [3:0] rows [0:7];
reg [3:0] cols [0:7];
reg [3:0] dist [0:7][0:7];
reg [3:0] dist_father_result;
reg [3:0] dist_elsa_result;
reg [15:0] A_sq;
reg [7:0] F_reg;
reg [3:0] N_reg;
reg [3:0] start_reg, goal_reg;

wire [3:0] row_i = rows[i_cnt];
wire [3:0] col_i = cols[i_cnt];
wire [3:0] row_j = rows[j_cnt];
wire [3:0] col_j = cols[j_cnt];

wire [3:0] row_diff = (row_i > row_j) ? (row_i - row_j) : (row_j - row_i);
wire [3:0] col_diff = (col_i > col_j) ? (col_i - col_j) : (col_j - col_i);
wire [7:0] row_diff_sq = row_diff * row_diff;
wire [7:0] col_diff_sq = col_diff * col_diff;
wire [15:0] euc_dist_sq = {8'd0, row_diff_sq} + {8'd0, col_diff_sq};

wire father_edge = ((row_i == row_j) && (col_diff <= F_reg[3:0])) || ((col_i == col_j) && (row_diff <= F_reg[3:0]));
wire elsas_edge = (euc_dist_sq <= A_sq);

wire [3:0] dist_ik = dist[i_cnt][k_cnt];
wire [3:0] dist_kj = dist[k_cnt][j_cnt];
wire [3:0] dist_ij = dist[i_cnt][j_cnt];
wire [3:0] new_dist = dist_ik + dist_kj;
wire update_condition = (dist_ik < 4'hF) && (dist_kj < 4'hF) && (new_dist < dist_ij);

always @(*) begin
    next_state = state;
    case (state)
        IDLE: if (start) next_state = BUILD_FATHER;
        BUILD_FATHER: begin
            if (i_cnt >= N_reg && j_cnt >= N_reg) next_state = FW_FATHER_K;
            else next_state = BUILD_FATHER;
        end
        FW_FATHER_K: begin
            if (k_cnt >= N_reg) next_state = SAVE_FATHER;
            else next_state = FW_FATHER_I;
        end
        FW_FATHER_I: begin
            if (i_cnt >= N_reg) next_state = FW_FATHER_K;
            else next_state = FW_FATHER_J;
        end
        FW_FATHER_J: begin
            if (j_cnt >= N_reg) next_state = FW_FATHER_I;
            else next_state = FW_FATHER_J;
        end
        SAVE_FATHER: next_state = BUILD_ELSA;
        BUILD_ELSA: begin
            if (i_cnt >= N_reg && j_cnt >= N_reg) next_state = FW_ELSA_K;
            else next_state = BUILD_ELSA;
        end
        FW_ELSA_K: begin
            if (k_cnt >= N_reg) next_state = COMPARE;
            else next_state = FW_ELSA_I;
        end
        FW_ELSA_I: begin
            if (i_cnt >= N_reg) next_state = FW_ELSA_K;
            else next_state = FW_ELSA_J;
        end
        FW_ELSA_J: begin
            if (j_cnt >= N_reg) next_state = FW_ELSA_I;
            else next_state = FW_ELSA_J;
        end
        COMPARE: next_state = DONE;
        DONE: next_state = DONE;
        default: next_state = IDLE;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 2'b00;
        i_cnt <= 4'd0;
        j_cnt <= 4'd0;
        k_cnt <= 4'd0;
        dist_father_result <= 4'hF;
        dist_elsa_result <= 4'hF;
        A_sq <= 16'd0;
        F_reg <= 8'd0;
        N_reg <= 4'd0;
        start_reg <= 4'd0;
        goal_reg <= 4'd0;
    end else begin
        state <= next_state;
        case (state)
            IDLE: if (start) begin
                N_reg <= N;
                start_reg <= start_idx;
                goal_reg <= goal_idx;
                F_reg <= F;
                rows[0] <= rows_data[3:0];
                rows[1] <= rows_data[7:4];
                rows[2] <= rows_data[11:8];
                rows[3] <= rows_data[15:12];
                rows[4] <= rows_data[19:16];
                rows[5] <= rows_data[23:20];
                rows[6] <= rows_data[27:24];
                rows[7] <= rows_data[31:28];
                cols[0] <= cols_data[3:0];
                cols[1] <= cols_data[7:4];
                cols[2] <= cols_data[11:8];
                cols[3] <= cols_data[15:12];
                cols[4] <= cols_data[19:16];
                cols[5] <= cols_data[23:20];
                cols[6] <= cols_data[27:24];
                cols[7] <= cols_data[31:28];
                i_cnt <= 4'd0;
                j_cnt <= 4'd0;
                k_cnt <= 4'd0;
                done <= 1'b0;
            end

            BUILD_FATHER: begin
                if (i_cnt < N_reg && j_cnt < N_reg) begin
                    if (i_cnt == j_cnt)
                        dist[i_cnt][j_cnt] <= 4'd0;
                    else if (father_edge)
                        dist[i_cnt][j_cnt] <= 4'd1;
                    else
                        dist[i_cnt][j_cnt] <= 4'hF;
                    if (j_cnt == N_reg - 4'd1) begin
                        j_cnt <= 4'd0;
                        if (i_cnt == N_reg - 4'd1) i_cnt <= 4'd0;
                        else i_cnt <= i_cnt + 4'd1;
                    end else begin
                        j_cnt <= j_cnt + 4'd1;
                    end
                end
            end

            FW_FATHER_K: begin
                i_cnt <= 4'd0;
            end

            FW_FATHER_I: begin
                j_cnt <= 4'd0;
            end

            FW_FATHER_J: begin
                if (j_cnt < N_reg) begin
                    if (update_condition) begin
                        dist[i_cnt][j_cnt] <= new_dist;
                    end
                    j_cnt <= j_cnt + 4'd1;
                end
            end

            SAVE_FATHER: begin
                dist_father_result <= dist[start_reg][goal_reg];
            end

            BUILD_ELSA: begin
                A_sq <= A * A;
                if (i_cnt < N_reg && j_cnt < N_reg) begin
                    if (i_cnt == j_cnt)
                        dist[i_cnt][j_cnt] <= 4'd0;
                    else if (elsas_edge)
                        dist[i_cnt][j_cnt] <= 4'd1;
                    else
                        dist[i_cnt][j_cnt] <= 4'hF;
                    if (j_cnt == N_reg - 4'd1) begin
                        j_cnt <= 4'd0;
                        if (i_cnt == N_reg - 4'd1) i_cnt <= 4'd0;
                        else i_cnt <= i_cnt + 4'd1;
                    end else begin
                        j_cnt <= j_cnt + 4'd1;
                    end
                end
            end

            FW_ELSA_K: begin
                i_cnt <= 4'd0;
            end

            FW_ELSA_I: begin
                j_cnt <= 4'd0;
            end

            FW_ELSA_J: begin
                if (j_cnt < N_reg) begin
                    if (update_condition) begin
                        dist[i_cnt][j_cnt] <= new_dist;
                    end
                    j_cnt <= j_cnt + 4'd1;
                end
            end

            COMPARE: begin
                if (dist_father_result == 4'hF && dist_elsa_result == 4'hF) begin
                    result <= NO_WAY;
                end else if (dist_father_result == 4'hF) begin
                    result <= GO_FOR_IT;
                end else if (dist_elsa_result == 4'hF) begin
                    result <= NO_CHANCE;
                end else if (dist_elsa_result == dist_father_result) begin
                    result <= SUCCESS;
                end else if (dist_elsa_result < dist_father_result) begin
                    result <= GO_FOR_IT;
                end else begin
                    result <= NO_CHANCE;
                end
                done <= 1'b1;
            end

            DONE: begin
            end
        endcase
    end
end

endmodule