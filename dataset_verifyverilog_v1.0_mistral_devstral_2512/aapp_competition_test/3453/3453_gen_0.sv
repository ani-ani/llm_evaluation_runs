module spike_cave (
    input clk,
    input rst_n,
    input start,
    input [2:0] N,
    input [3:0] M,
    input [15:0][39:0] edges,
    output reg [31:0] danger [0:7],
    output reg done
);

    parameter N_MAX = 8;
    parameter M_MAX = 16;
    parameter MOD = 1000000007;
    parameter INF = 64'hFFFFFFFF_FFFFFFFF;

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] LOAD_EDGES = 3'd2;
    localparam [2:0] FLOYD = 3'd3;
    localparam [2:0] SUM = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;
    reg [2:0] n_reg;
    reg [3:0] m_reg;
    reg [63:0] dist [0:7][0:7];
    reg [2:0] init_i, init_j;
    reg [3:0] edge_idx;
    reg [2:0] k_cnt, i_cnt, j_cnt;

    wire [3:0] A = edges[edge_idx][39:36];
    wire [3:0] B = edges[edge_idx][35:32];
    wire [31:0] L = edges[edge_idx][31:0];

    reg [63:0] temp_sum [0:7];
    integer i, j;

    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            temp_sum[i] = 64'd0;
            for (j = 0; j < 8; j = j + 1) begin
                if (j < n_reg) begin
                    temp_sum[i] = temp_sum[i] + dist[i][j];
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                danger[i] <= 32'd0;
                for (j = 0; j < 8; j = j + 1) begin
                    dist[i][j] <= 64'd0;
                end
            end
            init_i <= 3'd0;
            init_j <= 3'd0;
            edge_idx <= 4'd0;
            k_cnt <= 3'd0;
            i_cnt <= 3'd0;
            j_cnt <= 3'd0;
            n_reg <= 3'd0;
            m_reg <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            INIT: begin
                if (init_i == n_reg - 1 && init_j == n_reg - 1) next_state = LOAD_EDGES;
                else next_state = INIT;
            end
            LOAD_EDGES: begin
                if (edge_idx == m_reg - 1) next_state = FLOYD;
                else next_state = LOAD_EDGES;
            end
            FLOYD: begin
                if (k_cnt == n_reg - 1 && i_cnt == n_reg - 1 && j_cnt == n_reg - 1) next_state = SUM;
                else next_state = FLOYD;
            end
            SUM: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) danger[i] <= 32'd0;
            init_i <= 3'd0;
            init_j <= 3'd0;
            edge_idx <= 4'd0;
            k_cnt <= 3'd0;
            i_cnt <= 3'd0;
            j_cnt <= 3'd0;
            n_reg <= 3'd0;
            m_reg <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        n_reg <= N;
                        m_reg <= M;
                        init_i <= 3'd0;
                        init_j <= 3'd0;
                        edge_idx <= 4'd0;
                        k_cnt <= 3'd0;
                        i_cnt <= 3'd0;
                        j_cnt <= 3'd0;
                        done <= 1'b0;
                    end
                end
                INIT: begin
                    if (init_i == init_j) begin
                        dist[init_i][init_j] <= 64'd0;
                    end else begin
                        dist[init_i][init_j] <= INF;
                    end
                    if (init_j == n_reg - 1) begin
                        init_j <= 3'd0;
                        if (init_i == n_reg - 1) begin
                        end else begin
                            init_i <= init_i + 3'd1;
                        end
                    end else begin
                        init_j <= init_j + 3'd1;
                    end
                end
                LOAD_EDGES: begin
                    if (A != 3'd0 && B != 3'd0 && A <= n_reg && B <= n_reg) begin
                        dist[A - 1][B - 1] <= {32'b0, L};
                        dist[B - 1][A - 1] <= {32'b0, L};
                    end
                    if (edge_idx == m_reg - 1) begin
                    end else begin
                        edge_idx <= edge_idx + 4'd1;
                    end
                end
                FLOYD: begin
                    if (dist[i_cnt][k_cnt] < INF && dist[k_cnt][j_cnt] < INF) begin
                        if (dist[i_cnt][k_cnt] + dist[k_cnt][j_cnt] < dist[i_cnt][j_cnt]) begin
                            dist[i_cnt][j_cnt] <= dist[i_cnt][k_cnt] + dist[k_cnt][j_cnt];
                        end
                    end
                    if (j_cnt == n_reg - 1) begin
                        j_cnt <= 3'd0;
                        if (i_cnt == n_reg - 1) begin
                            i_cnt <= 3'd0;
                            if (k_cnt == n_reg - 1) begin
                            end else begin
                                k_cnt <= k_cnt + 3'd1;
                            end
                        end else begin
                            i_cnt <= i_cnt + 3'd1;
                        end
                    end else begin
                        j_cnt <= j_cnt + 3'd1;
                    end
                end
                SUM: begin
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < n_reg) begin
                            danger[i] <= temp_sum[i] % MOD;
                        end else begin
                            danger[i] <= 32'd0;
                        end
                    end
                    done <= 1'b1;
                end
                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule