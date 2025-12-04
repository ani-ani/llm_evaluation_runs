module network_optimizer (
    input clk,
    input rst_n,
    input start,
    input [2:0] size_A,
    input [2:0] size_B,
    input [63:0] adj_A,
    input [63:0] adj_B,
    output reg [15:0] min_cost,
    output reg done
);

typedef enum logic [3:0] {
    IDLE,
    SIZE_CAPTURE,
    COMPUTE_SSA,
    BFS_INIT_A,
    BFS_RUN_A,
    SUM_SSA_A,
    COMPUTE_SSB,
    BFS_INIT_B,
    BFS_RUN_B,
    SUM_SSB_B,
    FIND_MIN,
    CALC_RESULT,
    DONE
} state_t;

reg [3:0] state, next_state;
reg [2:0] size_A_r, size_B_r;
reg [63:0] adj_A_r, adj_B_r;
reg [2:0] cnt_u, cnt_v;                // Node counters
reg [3:0] bfs_cnt;                     // General BFS counter
reg [7:0] queue_vec;                   // BFS queue vector
reg [3:0] node_dist [7:0];             // Distance array
reg [10:0] SSA [7:0], SSB [7:0];      // Sum storage
reg [10:0] min_SSA, min_SSB;
reg [15:0] sum_A, sum_B;
reg [15:0] orig_cost_A, orig_cost_B;
wire [2:0] next_node = !queue_vec[0] ? queue_vec[1] ? 1 : queue_vec[2] ? 2 : queue_vec[3] ? 3 :
                         queue_vec[4] ? 4 : queue_vec[5] ? 5 : queue_vec[6] ? 6 : 7 : 0;

// Sequential state transition
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
end

// Main state machine
always_comb begin
    next_state = state;
    done = 0;
    case(state)
        IDLE:              if (start)   next_state = SIZE_CAPTURE;
        SIZE_CAPTURE:      next_state = COMPUTE_SSA;
        COMPUTE_SSA:       next_state = (cnt_u < size_A_r) ? BFS_INIT_A : COMPUTE_SSB;
        BFS_INIT_A:        next_state = BFS_RUN_A;
        BFS_RUN_A:         if (!queue_vec) next_state = SUM_SSA_A;
        SUM_SSA_A:         next_state = COMPUTE_SSA;
        COMPUTE_SSB:       next_state = (cnt_v < size_B_r) ? BFS_INIT_B : FIND_MIN;
        BFS_INIT_B:        next_state = BFS_RUN_B;
        BFS_RUN_B:         if (!queue_vec) next_state = SUM_SSB_B;
        SUM_SSB_B:         next_state = COMPUTE_SSB;
        FIND_MIN:          next_state = CALC_RESULT;
        CALC_RESULT:       next_state = DONE;
        DONE:              next_state = IDLE;
    endcase
end

// Node distance processing
always @(posedge clk) begin
    if (!rst_n) begin
        cnt_u  <= 0; cnt_v <= 0;
        SSA <= '{default:'0}; SSB <= '{default:'0};
        min_cost <= 0; done <= 0;
    end
    else begin
        case(state)
            SIZE_CAPTURE: begin
                size_A_r <= size_A; size_B_r <= size_B;
                adj_A_r <= adj_A; adj_B_r <= adj_B;
                cnt_u <= 0; cnt_v <= 0;
            end

            BFS_INIT_A: begin
                queue_vec <= (1 << cnt_u);
                for (int i=0; i<8; i=i+1)
                    node_dist[i] <= (i == cnt_u) ? 0 : 15;
            end

            BFS_RUN_A: begin
                if (queue_vec != 0) begin
                    for (int i=0; i<8; i=i+1)
                        if (adj_A_r[8*next_node + i] && i < size_A_r && node_dist[i] == 15) begin
                            node_dist[i] <= node_dist[next_node] + 1;
                            queue_vec <= queue_vec | (1 << i);
                        end
                    for (int i=0; i<8; i=i+1)
                        if (i == next_node) queue_vec <= queue_vec ^ (1 << i);
                end
            end

            SUM_SSA_A: begin
                SSA[cnt_u] <= \'0;
                for (int i=0; i < size_A_r; i=i+1)
                    SSA[cnt_u] <= SSA[cnt_u] + node_dist[i] * node_dist[i];
                cnt_u <= cnt_u + 1;
            end

            BFS_INIT_B: begin
                queue_vec <= (1 << cnt_v);
                for (int i=0; i<8; i=i+1)
                    node_dist[i] <= (i == cnt_v) ? 0 : 15;
            end

            BFS_RUN_B: begin
                if (queue_vec != 0) begin
                    for (int i=0; i<8; i=i+1)
                        if (adj_B_r[8*next_node + i] && i < size_B_r && node_dist[i] == 15) begin
                            node_dist[i] <= node_dist[next_node] + 1;
                            queue_vec <= queue_vec | (1 << i);
                        end
                    for (int i=0; i<8; i=i+1)
                        if (i == next_node) queue_vec <= queue_vec ^ (1 << i);
                end
            end

            SUM_SSB_B: begin
                SSB[cnt_v] <= \'0;
                for (int i=0; i < size_B_r; i=i+1)
                    SSB[cnt_v] <= SSB[cnt_v] + node_dist[i] * node_dist[i];
                cnt_v <= cnt_v + 1;
            end

            FIND_MIN: begin
                min_SSA <= 2047; min_SSB <= 2047;
                for (int i=0; i < size_A_r; i=i+1)
                    if (SSA[i] < min_SSA) min_SSA <= SSA[i];
                for (int i=0; i < size_B_r; i=i+1)
                    if (SSB[i] < min_SSB) min_SSB <= SSB[i];
                sum_A <= 0; sum_B <= 0;
                for (int i=0; i < size_A_r; i=i+1) sum_A <= sum_A + SSA[i];
                for (int i=0; i < size_B_r; i=i+1) sum_B <= sum_B + SSB[i];
            end

            CALC_RESULT: begin
                orig_cost_A <= sum_A / 2;
                orig_cost_B <= sum_B / 2;
                min_cost <= orig_cost_A + orig_cost_B + (size_A_r * size_B_r) +
                           (min_SSA * size_B_r) + (min_SSB * size_A_r);
            end

            DONE: done <= 1;
        endcase
    end
end
endmodule