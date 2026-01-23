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

    // Constants
    localparam [2:0] N_MAX = 3'd8;
    localparam [3:0] M_MAX = 4'd16;
    localparam [31:0] MOD = 32'd1000000007;
    localparam [63:0] INF = 64'hFFFFFFFF_FFFFFFFF;

    // State encoding
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] LOAD_EDGES = 3'd2;
    localparam [2:0] FLOYD = 3'd3;
    localparam [2:0] SUM = 3'd4;
    localparam [2:0] DONE = 3'd5;

    reg [2:0] state, next_state;

    // Captured N and M
    reg [2:0] n_reg;
    reg [3:0] m_reg;

    // Dist matrix - 64-bit for large distances
    reg [63:0] dist [0:7][0:7];
    reg [63:0] dist_k [0:7];
    reg [63:0] dist_i_k;
    reg [63:0] dist_k_j;
    reg [63:0] dist_i_j;
    reg [63:0] new_dist;

    // Counters and registers for INIT
    reg [2:0] init_i, init_j;

    // Counter for LOAD_EDGES
    reg [3:0] edge_idx;

    // Counters for FLOYD
    reg [2:0] k_cnt, i_cnt, j_cnt;

    // Edge decoding
    wire [3:0] A = edges[edge_idx][39:36];
    wire [3:0] B = edges[edge_idx][35:32];
    wire [31:0] L = edges[edge_idx][31:0];

    // Registers for SUM state
    reg [2:0] sum_i, sum_j;
    reg [63:0] current_sum;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            INIT: begin
                if (init_i == n_reg-1 && init_j == n_reg-1) next_state = LOAD_EDGES;
                else next_state = INIT;
            end
            LOAD_EDGES: begin
                if (edge_idx == m_reg-1) next_state = FLOYD;
                else next_state = LOAD_EDGES;
            end
            FLOYD: begin
                if (k_cnt == n_reg-1 && i_cnt == n_reg-1 && j_cnt == n_reg-1) next_state = SUM;
                else next_state = FLOYD;
            end
            SUM: begin
                if (sum_i == n_reg-1) next_state = DONE;
                else next_state = SUM;
            end
            DONE: begin
                next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            for (integer i = 0; i < 8; i = i + 1) danger[i] <= 0;
            init_i <= 0;
            init_j <= 0;
            edge_idx <= 0;
            k_cnt <= 0;
            i_cnt <= 0;
            j_cnt <= 0;
            n_reg <= 0;
            m_reg <= 0;
            sum_i <= 0;
            sum_j <= 0;
            current_sum <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        n_reg <= N;
                        m_reg <= M;
                        init_i <= 0;
                        init_j <= 0;
                        edge_idx <= 0;
                        k_cnt <= 0;
                        i_cnt <= 0;
                        j_cnt <= 0;
                        sum_i <= 0;
                        sum_j <= 0;
                        done <= 0;
                    end
                end

                INIT: begin
                    // Initialize dist matrix
                    if (init_i == init_j) begin
                        dist[init_i][init_j] <= 64'd0;
                    end else begin
                        dist[init_i][init_j] <= INF;
                    end
                    // Increment counters
                    if (init_j == n_reg-1) begin
                        init_j <= 0;
                        if (init_i == n_reg-1) begin
                            // Done
                        end else begin
                            init_i <= init_i + 1;
                        end
                    end else begin
                        init_j <= init_j + 1;
                    end
                end

                LOAD_EDGES: begin
                    // Process edge if within valid range
                    if (A != 0 && B != 0 && A <= n_reg && B <= n_reg) begin
                        // Convert to 0-based index and assign
                        dist[A-1][B-1] <= {32'b0, L};
                        dist[B-1][A-1] <= {32'b0, L};
                    end
                    // Increment edge_idx
                    if (edge_idx == m_reg-1) begin
                        // Done
                    end else begin
                        edge_idx <= edge_idx + 1;
                    end
                end

                FLOYD: begin
                    // Read values for calculation
                    dist_i_k <= dist[i_cnt][k_cnt];
                    dist_k_j <= dist[k_cnt][j_cnt];
                    dist_i_j <= dist[i_cnt][j_cnt];
                    
                    // Calculate new distance
                    if (dist_i_k < INF && dist_k_j < INF) begin
                        new_dist <= dist_i_k + dist_k_j;
                    end else begin
                        new_dist <= INF;
                    end
                    
                    // Update dist[i_cnt][j_cnt] if shorter path exists
                    if (dist_i_k < INF && dist_k_j < INF && dist_i_k + dist_k_j < dist_i_j) begin
                        dist[i_cnt][j_cnt] <= dist_i_k + dist_k_j;
                    end
                    
                    // Increment counters
                    if (j_cnt == n_reg-1) begin
                        j_cnt <= 0;
                        if (i_cnt == n_reg-1) begin
                            i_cnt <= 0;
                            if (k_cnt == n_reg-1) begin
                                // Done
                            end else begin
                                k_cnt <= k_cnt + 1;
                            end
                        end else begin
                            i_cnt <= i_cnt + 1;
                        end
                    end else begin
                        j_cnt <= j_cnt + 1;
                    end
                end

                SUM: begin
                    // Read current sum and dist value
                    if (sum_j == 0) begin
                        current_sum <= 0;
                    end
                    
                    // Add to sum
                    if (dist[sum_i][sum_j] < INF) begin
                        current_sum <= current_sum + dist[sum_i][sum_j];
                    end
                    
                    // Update danger level when moving to next row
                    if (sum_j == n_reg-1) begin
                        danger[sum_i] <= current_sum % MOD;
                    end
                    
                    // Increment counters
                    if (sum_j == n_reg-1) begin
                        sum_j <= 0;
                        if (sum_i == n_reg-1) begin
                            // Done
                        end else begin
                            sum_i <= sum_i + 1;
                        end
                    end else begin
                        sum_j <= sum_j + 1;
                    end
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule