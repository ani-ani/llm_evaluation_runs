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
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INIT_DIST = 2'd1;
    localparam [1:0] FLOYD_UPDATE = 2'd2;
    localparam [1:0] COMPUTE_DELIVERY = 2'd3;
    localparam [1:0] DONE_STATE = 2'd4;

    // Internal signals
    reg [1:0] state, next_state;
    reg [3:0] i_cnt, j_cnt, k_cnt;
    reg [3:0] order_idx;
    reg [31:0] dist [0:7][0:7];
    reg [31:0] D_prev, D_curr, T_min;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Constants
    localparam [31:0] INF = 32'h7FFFFFFF;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT_DIST;
                else
                    next_state = IDLE;
            end
            
            INIT_DIST: begin
                if (i_cnt < n) begin
                    if (j_cnt < n)
                        next_state = INIT_DIST;
                    else
                        next_state = INIT_DIST;
                end else
                    next_state = FLOYD_UPDATE;
            end
            
            FLOYD_UPDATE: begin
                if (k_cnt < n) begin
                    if (i_cnt < n) begin
                        if (j_cnt < n)
                            next_state = FLOYD_UPDATE;
                        else
                            next_state = FLOYD_UPDATE;
                    end else
                        next_state = FLOYD_UPDATE;
                end else begin
                    if (i_cnt < m)
                        next_state = FLOYD_UPDATE;
                    else
                        next_state = COMPUTE_DELIVERY;
                end
            end
            
            COMPUTE_DELIVERY: begin
                if (order_idx < k)
                    next_state = COMPUTE_DELIVERY;
                else
                    next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // State register with reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            i_cnt <= 4'd0;
            j_cnt <= 4'd0;
            k_cnt <= 4'd0;
            order_idx <= 4'd0;
            D_prev <= 32'd0;
            D_curr <= 32'd0;
            T_min <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
        end
    end

    // Distance matrix initialization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integer i, j;
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    dist[i][j] <= 32'd0;
                end
            end
        end else begin
            if (state == INIT_DIST) begin
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
                end
            end
        end
    end

    // Floyd-Warshall algorithm
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized
        end else begin
            if (state == FLOYD_UPDATE) begin
                if (k_cnt < n) begin
                    if (i_cnt < n) begin
                        if (j_cnt < n) begin
                            if (dist[i_cnt][k_cnt] != INF && dist[k_cnt][j_cnt] != INF) begin
                                if (dist[i_cnt][k_cnt] + dist[k_cnt][j_cnt] < dist[i_cnt][j_cnt]) begin
                                    dist[i_cnt][j_cnt] <= dist[i_cnt][k_cnt] + dist[k_cnt][j_cnt];
                                end
                            end
                            j_cnt <= j_cnt + 4'd1;
                        end else begin
                            j_cnt <= 4'd0;
                            i_cnt <= i_cnt + 4'd1;
                        end
                    end else begin
                        i_cnt <= 4'd0;
                        k_cnt <= k_cnt + 4'd1;
                    end
                end else begin
                    if (i_cnt < m) begin
                        if (edge_u[i_cnt] > 0 && edge_u[i_cnt] <= n && 
                            edge_v[i_cnt] > 0 && edge_v[i_cnt] <= n) begin
                            dist[edge_u[i_cnt]-1][edge_v[i_cnt]-1] <= edge_d[i_cnt];
                            dist[edge_v[i_cnt]-1][edge_u[i_cnt]-1] <= edge_d[i_cnt];
                        end
                        i_cnt <= i_cnt + 4'd1;
                    end
                end
            end
        end
    end

    // Delivery computation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized
        end else begin
            if (state == COMPUTE_DELIVERY) begin
                if (order_idx < k) begin
                    if (order_idx == 0) begin
                        if (order_u[0] > 0 && order_u[0] <= n) begin
                            if (dist[0][order_u[0]-1] > order_t[0]) begin
                                D_prev <= dist[0][order_u[0]-1];
                                T_min <= dist[0][order_u[0]-1] - order_s[0];
                            end else begin
                                D_prev <= order_t[0];
                                T_min <= order_t[0] - order_s[0];
                            end
                        end
                        order_idx <= order_idx + 4'd1;
                    end else begin
                        if (order_u[order_idx-1] > 0 && order_u[order_idx-1] <= n &&
                            order_u[order_idx] > 0 && order_u[order_idx] <= n) begin
                            
                            if (dist[order_u[order_idx-1]-1][order_u[order_idx]-1] != INF) begin
                                reg [31:0] travel_time = dist[order_u[order_idx-1]-1][order_u[order_idx]-1];
                                reg [31:0] arrival_time = D_prev + travel_time;
                                reg [31:0] new_T;
                                
                                if (arrival_time > order_t[order_idx]) begin
                                    D_curr <= arrival_time;
                                    new_T = arrival_time - order_s[order_idx];
                                end else begin
                                    D_curr <= order_t[order_idx];
                                    new_T = order_t[order_idx] - order_s[order_idx];
                                end
                                
                                if (new_T > T_min)
                                    T_min <= new_T;
                                
                                D_prev <= (arrival_time > order_t[order_idx]) ? arrival_time : order_t[order_idx];
                            end
                        end
                        order_idx <= order_idx + 4'd1;
                    end
                end else begin
                    result <= T_min;
                    done <= 1'b1;
                end
            end
        end
    end

    // Done signal handling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (state == DONE_STATE) begin
                done <= 1'b0;
            end
        end
    end

endmodule