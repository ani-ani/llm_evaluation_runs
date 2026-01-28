module pizza_delivery_optimizer (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] m,
    input [3:0] k,
    input [3:0] edge_u [0:15],
    input [3:0] edge_v [0:15],
    input [31:0] edge_d [0:15],
    input [31:0] order_s [0:7],
    input [3:0] order_u [0:7],
    input [31:0] order_t [0:7],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] INIT_DIST     = 4'd1;
    localparam [3:0] FLOYD_START   = 4'd2;
    localparam [3:0] FLOYD_UPDATE  = 4'd3;
    localparam [3:0] SET_EDGES     = 4'd4;
    localparam [3:0] COMPUTE_START = 4'd5;
    localparam [3:0] COMPUTE_ORDER = 4'd6;
    localparam [3:0] DONE_STATE    = 4'd7;
    localparam [3:0] FLOYD_LOOP    = 4'd8;

    // Internal registers
    reg [3:0] state;
    reg [3:0] i_cnt, j_cnt, k_cnt;
    reg [31:0] dist [0:7][0:7];
    reg [31:0] D_prev, D_curr, T_min;
    reg [3:0] order_idx;
    reg [3:0] edge_idx;
    reg [3:0] k_val;
    
    // Temporary values for comparison
    reg [31:0] new_dist;
    reg [31:0] travel_time;
    reg [31:0] arrival_time;
    reg [31:0] new_T;
    
    // Constants
    localparam [31:0] INF = 32'h7FFFFFFF;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            i_cnt <= 4'd0;
            j_cnt <= 4'd0;
            k_cnt <= 4'd0;
            order_idx <= 4'd0;
            edge_idx <= 4'd0;
            k_val <= 4'd0;
            D_prev <= 32'd0;
            D_curr <= 32'd0;
            T_min <= 32'd0;
            new_dist <= 32'd0;
            travel_time <= 32'd0;
            arrival_time <= 32'd0;
            new_T <= 32'd0;
            // Initialize dist array
            for (i_cnt = 0; i_cnt < 8; i_cnt = i_cnt + 1) begin
                for (j_cnt = 0; j_cnt < 8; j_cnt = j_cnt + 1) begin
                    dist[i_cnt][j_cnt] <= INF;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT_DIST;
                        i_cnt <= 4'd0;
                        j_cnt <= 4'd0;
                    end
                end
                
                INIT_DIST: begin
                    // Initialize distance matrix
                    if (i_cnt < n) begin
                        if (j_cnt < n) begin
                            if (i_cnt == j_cnt)
                                dist[i_cnt][j_cnt] <= 32'd0;
                            else
                                dist[i_cnt][j_cnt] <= INF;
                            j_cnt <= j_cnt + 4'd1;
                        end else begin
                            j_cnt <= 4'd0;
                            i_cnt <= i_cnt + 4'd1;
                        end
                    end else begin
                        state <= FLOYD_START;
                        k_cnt <= 4'd0;
                        i_cnt <= 4'd0;
                        j_cnt <= 4'd0;
                    end
                end
                
                FLOYD_START: begin
                    // Start Floyd-Warshall outer loop
                    if (k_cnt < n) begin
                        k_val <= k_cnt;
                        i_cnt <= 4'd0;
                        state <= FLOYD_LOOP;
                    end else begin
                        edge_idx <= 4'd0;
                        state <= SET_EDGES;
                    end
                end
                
                FLOYD_LOOP: begin
                    // Floyd-Warshall middle loop
                    if (i_cnt < n) begin
                        if (dist[i_cnt][k_val] != INF) begin
                            j_cnt <= 4'd0;
                            state <= FLOYD_UPDATE;
                        end else begin
                            i_cnt <= i_cnt + 4'd1;
                        end
                    end else begin
                        k_cnt <= k_cnt + 4'd1;
                        state <= FLOYD_START;
                    end
                end
                
                FLOYD_UPDATE: begin
                    // Floyd-Warshall inner loop
                    if (j_cnt < n) begin
                        if (dist[k_val][j_cnt] != INF) begin
                            new_dist <= dist[i_cnt][k_val] + dist[k_val][j_cnt];
                            if (dist[i_cnt][k_val] + dist[k_val][j_cnt] < dist[i_cnt][j_cnt]) begin
                                dist[i_cnt][j_cnt] <= dist[i_cnt][k_val] + dist[k_val][j_cnt];
                            end
                        end
                        j_cnt <= j_cnt + 4'd1;
                    end else begin
                        i_cnt <= i_cnt + 4'd1;
                        state <= FLOYD_LOOP;
                    end
                end
                
                SET_EDGES: begin
                    // Set actual edge distances
                    if (edge_idx < m) begin
                        if (edge_u[edge_idx] <= n && edge_v[edge_idx] <= n && 
                            edge_u[edge_idx] > 0 && edge_v[edge_idx] > 0) begin
                            dist[edge_u[edge_idx]-1][edge_v[edge_idx]-1] <= edge_d[edge_idx];
                            dist[edge_v[edge_idx]-1][edge_u[edge_idx]-1] <= edge_d[edge_idx];
                        end
                        edge_idx <= edge_idx + 4'd1;
                    end else begin
                        // Re-run Floyd-Warshall to propagate new edges
                        k_cnt <= 4'd0;
                        i_cnt <= 4'd0;
                        j_cnt <= 4'd0;
                        state <= FLOYD_START;
                        edge_idx <= 4'd0; // Mark that we already did edge addition
                        if (edge_idx > 0) begin
                            // After setting edges, we need to propagate
                            // We'll reuse FLOYD_START logic but skip SET_EDGES after
                            if (edge_u[0] <= n) begin
                                state <= FLOYD_START;
                            end else begin
                                state <= COMPUTE_START;
                            end
                        end else begin
                            state <= COMPUTE_START;
                        end
                    end
                end
                
                COMPUTE_START: begin
                    order_idx <= 4'd0;
                    T_min <= 32'd0;
                    if (k > 0) begin
                        // First order
                        if (order_u[0] > 0 && order_u[0] <= n) begin
                            if (dist[0][order_u[0]-1] > order_t[0]) begin
                                D_prev <= dist[0][order_u[0]-1];
                                new_T <= dist[0][order_u[0]-1] - order_s[0];
                                T_min <= dist[0][order_u[0]-1] - order_s[0];
                            end else begin
                                D_prev <= order_t[0];
                                new_T <= order_t[0] - order_s[0];
                                T_min <= order_t[0] - order_s[0];
                            end
                        end else begin
                            // Invalid order, default handling
                            D_prev <= order_t[0];
                            new_T <= order_t[0] - order_s[0];
                            T_min <= order_t[0] - order_s[0];
                        end
                        order_idx <= 4'd1;
                        state <= COMPUTE_ORDER;
                    end else begin
                        result <= 32'd0;
                        state <= DONE_STATE;
                    end
                end
                
                COMPUTE_ORDER: begin
                    if (order_idx < k) begin
                        // Subsequent orders
                        if (order_u[order_idx-1] > 0 && order_u[order_idx-1] <= n &&
                            order_u[order_idx] > 0 && order_u[order_idx] <= n) begin
                            
                            travel_time <= dist[order_u[order_idx]-1][order_u[order_idx-1]-1];
                            arrival_time <= D_prev + dist[order_u[order_idx]-1][order_u[order_idx-1]-1];
                            
                            if (D_prev + dist[order_u[order_idx]-1][order_u[order_idx-1]-1] > order_t[order_idx]) begin
                                D_curr <= D_prev + dist[order_u[order_idx]-1][order_u[order_idx-1]-1];
                                new_T <= D_prev + dist[order_u[order_idx]-1][order_u[order_idx-1]-1] - order_s[order_idx];
                                if (D_prev + dist[order_u[order_idx]-1][order_u[order_idx-1]-1] - order_s[order_idx] > T_min) begin
                                    T_min <= D_prev + dist[order_u[order_idx]-1][order_u[order_idx-1]-1] - order_s[order_idx];
                                end
                            end else begin
                                D_curr <= order_t[order_idx];
                                new_T <= order_t[order_idx] - order_s[order_idx];
                                if (order_t[order_idx] - order_s[order_idx] > T_min) begin
                                    T_min <= order_t[order_idx] - order_s[order_idx];
                                end
                            end
                            
                            D_prev <= (D_prev + dist[order_u[order_idx]-1][order_u[order_idx-1]-1] > order_t[order_idx]) ? 
                                      (D_prev + dist[order_u[order_idx]-1][order_u[order_idx-1]-1]) : order_t[order_idx];
                        end
                        order_idx <= order_idx + 4'd1;
                    end else begin
                        result <= T_min;
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule