module trekking #(
    parameter N = 5,
    parameter M = 6,
    parameter [3:0] U [0:7] = '{5,0,1,2,2,4,0,0}, // Pad unused with 0
    parameter [3:0] V [0:7] = '{1,3,2,3,4,3,0,0},
    parameter [3:0] D [0:7] = '{2,8,11,5,2,9,0,0}
) (
    input clk,
    input rst_n,
    input start,
    output reg [7:0] result,
    output reg done
);

// State machine states
localparam [3:0] S_IDLE        = 4'd0;
localparam [3:0] S_INIT        = 4'd1;
localparam [3:0] S_FLOYD_INIT  = 4'd2;
localparam [3:0] S_FLOYD_K     = 4'd3;
localparam [3:0] S_FLOYD_I     = 4'd4;
localparam [3:0] S_FLOYD_J     = 4'd5;
localparam [3:0] S_FLOYD_UPD   = 4'd6;
localparam [3:0] S_KNIGHT_CALC = 4'd7;
localparam [3:0] S_DK_INIT     = 4'd8;
localparam [3:0] S_DK_LOOP     = 4'd9;
localparam [3:0] S_DK_RELAX    = 4'd10;
localparam [3:0] S_DK_SLEEP    = 4'd11;
localparam [3:0] S_DK_RESULT   = 4'd12;
localparam [3:0] S_DONE        = 4'd13;

// Constants
localparam [7:0] INF       = 8'hFF;
localparam [3:0] NO_EDGE   = 4'hF;
localparam [3:0] MAX_NODES = 4'd8;

reg [3:0] state, next_state;

// Floyd-Warshall registers
reg [3:0] i_reg, j_reg, k_reg, e_reg;
reg [7:0] dist [0:7][0:7];
reg [3:0] adj  [0:7][0:7];
reg [7:0] knight_elapsed;

// Dijkstra registers
reg [7:0] dist_state [0:103]; // 8 nodes * 13 states
reg visited [0:103];
reg [3:0] current_node;
reg [3:0] current_hours;
reg [7:0] min_dist;
reg [7:0] day_elapsed;

// Temporary registers
reg [7:0] temp_dist;
reg [3:0] temp_state_idx;
reg [7:0] temp_new_dist;

integer i, j; // Loop counters

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done <= 1'b0;
        result <= 8'd0;
    end else begin
        state <= next_state;
        if (state == S_DONE) begin
            result <= day_elapsed - knight_elapsed;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        S_IDLE:        if (start) next_state = S_INIT;
        S_INIT:        if (e_reg == 4'd7) next_state = S_FLOYD_INIT;
        S_FLOYD_INIT:  next_state = S_FLOYD_K;
        S_FLOYD_K:     next_state = S_FLOYD_I;
        S_FLOYD_I:     next_state = S_FLOYD_J;
        S_FLOYD_J:     next_state = S_FLOYD_UPD;
        S_FLOYD_UPD:   begin
            if (j_reg < MAX_NODES-1) next_state = S_FLOYD_J;
            else if (i_reg < MAX_NODES-1) next_state = S_FLOYD_I;
            else if (k_reg < MAX_NODES-1) next_state = S_FLOYD_K;
            else next_state = S_KNIGHT_CALC;
        end
        S_KNIGHT_CALC: next_state = S_DK_INIT;
        S_DK_INIT:     next_state = S_DK_LOOP;
        S_DK_LOOP:     next_state = S_DK_RELAX;
        S_DK_RELAX:    next_state = S_DK_SLEEP;
        S_DK_SLEEP:    next_state = S_DONE;
        S_DK_RESULT:   next_state = S_DONE;
        S_DONE:        next_state = S_IDLE;
        default:       next_state = S_IDLE;
    endcase
end

// Data path
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Initialize arrays
        for (i = 0; i < MAX_NODES; i = i + 1) begin
            for (j = 0; j < MAX_NODES; j = j + 1) begin
                dist[i][j] <= INF;
                adj[i][j]  <= NO_EDGE;
            end
        end
        for (i = 0; i < 104; i = i + 1) begin
            dist_state[i] <= INF;
            visited[i]  <= 1'b0;
        end
        
        // Reset counters
        i_reg <= 4'd0;
        j_reg <= 4'd0;
        k_reg <= 4'd0;
        e_reg <= 4'd0;
        knight_elapsed <= 8'd0;
        day_elapsed <= 8'd0;
        
    end else begin
        case (state)
            S_INIT: begin
                if (e_reg < M) begin
                    adj[U[e_reg]][V[e_reg]] <= (D[e_reg] < adj[U[e_reg]][V[e_reg]]) ? D[e_reg] : adj[U[e_reg]][V[e_reg]];
                    adj[V[e_reg]][U[e_reg]] <= (D[e_reg] < adj[V[e_reg]][U[e_reg]]) ? D[e_reg] : adj[V[e_reg]][U[e_reg]];
                    e_reg <= e_reg + 1;
                end
            end
            
            S_FLOYD_INIT: begin
                k_reg <= 4'd0;
                for (i = 0; i < MAX_NODES; i = i + 1) begin
                    for (j = 0; j < MAX_NODES; j = j + 1) begin
                        if (i == j) dist[i][j] <= 8'd0;
                        else if (adj[i][j] != NO_EDGE) dist[i][j] <= {4'd0, adj[i][j]};
                        else dist[i][j] <= INF;
                    end
                end
            end
            
            S_FLOYD_K: begin
                i_reg <= 4'd0;
                k_reg <= k_reg + 1;
            end
            
            S_FLOYD_I: begin
                j_reg <= 4'd0;
                i_reg <= i_reg + 1;
            end
            
            S_FLOYD_J: begin
                j_reg <= j_reg + 1;
            end
            
            S_FLOYD_UPD: begin
                temp_dist = dist[i_reg][k_reg] + dist[k_reg][j_reg];
                if (temp_dist < dist[i_reg][j_reg]) begin
                    dist[i_reg][j_reg] <= temp_dist;
                end
            end
            
            S_KNIGHT_CALC: begin
                // Calculate knight_elapsed (simplified)
                knight_elapsed <= (dist[0][N-1] <= 12) ? 
                    dist[0][N-1] : 
                    (dist[0][N-1] + ((dist[0][N-1] + 4'd11) >> 4'd3) * 4'd12);
            end
            
            S_DK_INIT: begin
                dist_state[0] <= 8'd0;
                visited[0] <= 1'b0;
            end
            
            S_DK_LOOP: begin
                min_dist <= INF;
                for (i = 0; i < 104; i = i + 1) begin
                    if (!visited[i] && dist_state[i] < min_dist) begin
                        min_dist <= dist_state[i];
                        current_node <= i / 13;
                        current_hours <= (i % 13);
                    end
                end
            end
            
            S_DK_RELAX: begin
                // Edge relaxation logic
                for (j = 0; j < MAX_NODES; j = j + 1) begin
                    if (adj[current_node][j] != NO_EDGE) begin
                        if ((current_hours + adj[current_node][j]) <= 12) begin
                            temp_state_idx = j * 13 + (current_hours + adj[current_node][j]);
                            temp_new_dist = min_dist + adj[current_node][j];
                            if (temp_new_dist < dist_state[temp_state_idx]) begin
                                dist_state[temp_state_idx] <= temp_new_dist;
                            end
                        end
                    end
                end
            end
            
            S_DK_SLEEP: begin
                if (current_hours > 0) begin
                    temp_state_idx = current_node * 13;
                    temp_new_dist = min_dist + 24 - current_hours;
                    if (temp_new_dist < dist_state[temp_state_idx]) begin
                        dist_state[temp_state_idx] <= temp_new_dist;
                    end
                end
            end
            
            S_DK_RESULT: begin
                // Find minimal time to last node
                day_elapsed <= INF;
                for (i = 0; i < 13; i = i + 1) begin
                    if (dist_state[(N-1)*13 + i] < day_elapsed) begin
                        day_elapsed <= dist_state[(N-1)*13 + i];
                    end
                end
            end
        endcase
    end
end

endmodule
