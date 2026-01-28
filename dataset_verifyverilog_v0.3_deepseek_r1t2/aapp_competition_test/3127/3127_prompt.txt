module network_optimal_path #(
    parameter MAX_N = 8,
    parameter MAX_M = 16,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 4,
    parameter INF = 32'hFFFF_FFFF
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [ADDR_WIDTH-1:0] n,
    input wire [ADDR_WIDTH-1:0] m,
    input wire [ADDR_WIDTH-1:0] a_i [0:MAX_M-1],
    input wire [ADDR_WIDTH-1:0] b_i [0:MAX_M-1],
    input wire [DATA_WIDTH-1:0] len_i [0:MAX_M-1],
    output reg done,
    output reg [MAX_N-1:0] unused_mask
);

// Internal arrays
reg [ADDR_WIDTH-1:0] edge_a [0:MAX_M-1];
reg [ADDR_WIDTH-1:0] edge_b [0:MAX_M-1];
reg [DATA_WIDTH-1:0] edge_len [0:MAX_M-1];

reg [DATA_WIDTH-1:0] dp1 [0:MAX_N-1][0:MAX_N-1];
reg [DATA_WIDTH-1:0] dp2 [0:MAX_N-1][0:MAX_N-1];

reg [DATA_WIDTH-1:0] dist_len [0:MAX_N-1];
reg [DATA_WIDTH-1:0] dist_edge [0:MAX_N-1];
reg [DATA_WIDTH-1:0] rev_len [0:MAX_N-1];
reg [DATA_WIDTH-1:0] rev_edge [0:MAX_N-1];

reg [DATA_WIDTH-1:0] dist_len_n;
reg [DATA_WIDTH-1:0] dist_edge_n;

// State machine
reg [3:0] state;
localparam S_IDLE          = 4'd0;
localparam S_LOAD_EDGES    = 4'd1;
localparam S_INIT_FWD      = 4'd2;
localparam S_FWD_LOOP_K    = 4'd3;
localparam S_FWD_LOOP_EDGES= 4'd4;
localparam S_FWD_COMPUTE   = 4'd5;
localparam S_INIT_BWD      = 4'd6;
localparam S_BWD_LOOP_K    = 4'd7;
localparam S_BWD_LOOP_EDGES= 4'd8;
localparam S_BWD_COMPUTE   = 4'd9;
localparam S_COMPUTE_RES   = 4'd10;
localparam S_DONE          = 4'd11;

// Counters
reg [ADDR_WIDTH-1:0] k_cnt;
reg [ADDR_WIDTH-1:0] edge_cnt;
reg [ADDR_WIDTH-1:0] v_cnt;
reg [ADDR_WIDTH-1:0] k2_cnt;
reg [ADDR_WIDTH-1:0] node_idx;

// Temporary variables
reg [DATA_WIDTH-1:0] new_val_a, new_val_b;
reg used;

integer i, j;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        done <= 0;
        unused_mask <= 0;
        state <= S_IDLE;
        // Initialize dp arrays to INF
        for (i = 0; i < MAX_N; i = i + 1) begin
            for (j = 0; j < MAX_N; j = j + 1) begin
                dp1[i][j] <= INF;
                dp2[i][j] <= INF;
            end
        end
    end else begin
        case (state)
            S_IDLE: begin
                done <= 0;
                if (start) begin
                    state <= S_LOAD_EDGES;
                    edge_cnt <= 0;
                end
            end

            S_LOAD_EDGES: begin
                if (edge_cnt < m) begin
                    edge_a[edge_cnt] <= a_i[edge_cnt];
                    edge_b[edge_cnt] <= b_i[edge_cnt];
                    edge_len[edge_cnt] <= len_i[edge_cnt];
                    edge_cnt <= edge_cnt + 1;
                end else if (edge_cnt < MAX_M) begin
                    edge_a[edge_cnt] <= 0;
                    edge_b[edge_cnt] <= 0;
                    edge_len[edge_cnt] <= 0;
                    edge_cnt <= edge_cnt + 1;
                end else begin
                    state <= S_INIT_FWD;
                end
            end

            S_INIT_FWD: begin
                for (i = 0; i < MAX_N; i = i + 1) begin
                    for (j = 0; j < MAX_N; j = j + 1) begin
                        dp1[i][j] <= INF;
                    end
                end
                if (n >= 1) begin
                    dp1[0][0] <= 0;
                end
                k_cnt <= 1;
                state <= S_FWD_LOOP_K;
            end

            S_FWD_LOOP_K: begin
                if (k_cnt < n) begin
                    edge_cnt <= 0;
                    state <= S_FWD_LOOP_EDGES;
                end else begin
                    state <= S_FWD_COMPUTE;
                    v_cnt <= 0;
                    k2_cnt <= 0;
                    for (i = 0; i < MAX_N; i = i + 1) begin
                        dist_len[i] <= INF;
                        dist_edge[i] <= INF;
                    end
                end
            end

            S_FWD_LOOP_EDGES: begin
                if (edge_cnt < m) begin
                    if (edge_a[edge_cnt] < n && edge_b[edge_cnt] < n) begin
                        if (dp1[k_cnt-1][edge_a[edge_cnt]] < INF) begin
                            new_val_b = dp1[k_cnt][edge_b[edge_cnt]];
                            if (dp1[k_cnt-1][edge_a[edge_cnt]] + edge_len[edge_cnt] < new_val_b) begin
                                new_val_b = dp1[k_cnt-1][edge_a[edge_cnt]] + edge_len[edge_cnt];
                            end
                            dp1[k_cnt][edge_b[edge_cnt]] <= new_val_b;
                        end
                        if (dp1[k_cnt-1][edge_b[edge_cnt]] < INF) begin
                            new_val_a = dp1[k_cnt][edge_a[edge_cnt]];
                            if (dp1[k_cnt-1][edge_b[edge_cnt]] + edge_len[edge_cnt] < new_val_a) begin
                                new_val_a = dp1[k_cnt-1][edge_b[edge_cnt]] + edge_len[edge_cnt];
                            end
                            dp1[k_cnt][edge_a[edge_cnt]] <= new_val_a;
                        end
                    end
                    edge_cnt <= edge_cnt + 1;
                end else begin
                    k_cnt <= k_cnt + 1;
                    state <= S_FWD_LOOP_K;
                end
            end

            S_FWD_COMPUTE: begin
                if (v_cnt < n) begin
                    if (k2_cnt < n) begin
                        if (dp1[k2_cnt][v_cnt] < dist_len[v_cnt]) begin
                            dist_len[v_cnt] <= dp1[k2_cnt][v_cnt];
                        end
                        if (dp1[k2_cnt][v_cnt] < INF) begin
                            if (k2_cnt < dist_edge[v_cnt]) begin
                                dist_edge[v_cnt] <= k2_cnt;
                            end
                        end
                        k2_cnt <= k2_cnt + 1;
                    end else begin
                        k2_cnt <= 0;
                        v_cnt <= v_cnt + 1;
                    end
                end else begin
                    state <= S_INIT_BWD;
                end
            end

            S_INIT_BWD: begin
                for (i = 0; i < MAX_N; i = i + 1) begin
                    for (j = 0; j < MAX_N; j = j + 1) begin
                        dp2[i][j] <= INF;
                    end
                end
                if (n >= 1) begin
                    dp2[0][n-1] <= 0;
                end
                k_cnt <= 1;
                state <= S_BWD_LOOP_K;
            end

            S_BWD_LOOP_K: begin
                if (k_cnt < n) begin
                    edge_cnt <= 0;
                    state <= S_BWD_LOOP_EDGES;
                end else begin
                    state <= S_BWD_COMPUTE;
                    v_cnt <= 0;
                    k2_cnt <= 0;
                    for (i = 0; i < MAX_N; i = i + 1) begin
                        rev_len[i] <= INF;
                        rev_edge[i] <= INF;
                    end
                end
            end

            S_BWD_LOOP_EDGES: begin
                if (edge_cnt < m) begin
                    if (edge_a[edge_cnt] < n && edge_b[edge_cnt] < n) begin
                        if (dp2[k_cnt-1][edge_b[edge_cnt]] < INF) begin
                            new_val_a = dp2[k_cnt][edge_a[edge_cnt]];
                            if (dp2[k_cnt-1][edge_b[edge_cnt]] + edge_len[edge_cnt] < new_val_a) begin
                                new_val_a = dp2[k_cnt-1][edge_b[edge_cnt]] + edge_len[edge_cnt];
                            end
                            dp2[k_cnt][edge_a[edge_cnt]] <= new_val_a;
                        end
                        if (dp2[k_cnt-1][edge_a[edge_cnt]] < INF) begin
                            new_val_b = dp2[k_cnt][edge_b[edge_cnt]];
                            if (dp2[k_cnt-1][edge_a[edge_cnt]] + edge_len[edge_cnt] < new_val_b) begin
                                new_val_b = dp2[k_cnt-1][edge_a[edge_cnt]] + edge_len[edge_cnt];
                            end
                            dp2[k_cnt][edge_b[edge_cnt]] <= new_val_b;
                        end
                    end
                    edge_cnt <= edge_cnt + 1;
                end else begin
                    k_cnt <= k_cnt + 1;
                    state <= S_BWD_LOOP_K;
                end
            end

            S_BWD_COMPUTE: begin
                if (v_cnt < n) begin
                    if (k2_cnt < n) begin
                        if (dp2[k2_cnt][v_cnt] < rev_len[v_cnt]) begin
                            rev_len[v_cnt] <= dp2[k2_cnt][v_cnt];
                        end
                        if (dp2[k2_cnt][v_cnt] < INF) begin
                            if (k2_cnt < rev_edge[v_cnt]) begin
                                rev_edge[v_cnt] <= k2_cnt;
                            end
                        end
                        k2_cnt <= k2_cnt + 1;
                    end else begin
                        k2_cnt <= 0;
                        v_cnt <= v_cnt + 1;
                    end
                end else begin
                    dist_len_n <= dist_len[n-1];
                    dist_edge_n <= dist_edge[n-1];
                    node_idx <= 0;
                    state <= S_COMPUTE_RES;
                end
            end

            S_COMPUTE_RES: begin
                if (node_idx < n) begin
                    if (node_idx == 0 || node_idx == n-1) begin
                        used = 1;
                    end else begin
                        used = ((dist_len[node_idx] + rev_len[node_idx] == dist_len_n) ||
                                (dist_edge[node_idx] + rev_edge[node_idx] == dist_edge_n));
                    end
                    if (!used) begin
                        unused_mask[node_idx] <= 1;
                    end else begin
                        unused_mask[node_idx] <= 0;
                    end
                    node_idx <= node_idx + 1;
                end else begin
                    state <= S_DONE;
                end
            end

            S_DONE: begin
                done <= 1;
                state <= S_IDLE;
            end

            default: state <= S_IDLE;
        endcase
    end
end

endmodule