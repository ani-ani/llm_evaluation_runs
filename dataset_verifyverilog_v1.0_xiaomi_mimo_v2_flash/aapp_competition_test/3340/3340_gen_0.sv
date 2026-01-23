module flight_optimizer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] adj_flat,
    output reg [2:0] min_diameter,
    output reg [2:0] remove_u,
    output reg [2:0] remove_v,
    output reg [2:0] add_u,
    output reg [2:0] add_v,
    output reg done
);

    // State definitions
    localparam [4:0] IDLE         = 5'd0;
    localparam [4:0] INIT         = 5'd1;
    localparam [4:0] FIND_EDGE    = 5'd2;
    localparam [4:0] REMOVE_EDGE  = 5'd3;
    localparam [4:0] BFS_COMP1    = 5'd4;
    localparam [4:0] BFS_COMP2    = 5'd5;
    localparam [4:0] BFS_DIST     = 5'd6;
    localparam [4:0] CALC_RADIUS  = 5'd7;
    localparam [4:0] CALC_CAND    = 5'd8;
    localparam [4:0] UPDATE_BEST  = 5'd9;
    localparam [4:0] RESTORE_EDGE = 5'd10;
    localparam [4:0] DONE_STATE   = 5'd11;

    // Registers
    reg [4:0] state, next_state;
    reg [63:0] adj_reg;
    reg [63:0] temp_adj;
    reg [2:0] edge_u, edge_v;
    reg [2:0] next_u, next_v;
    reg [2:0] best_diam;
    reg [2:0] best_ru, best_rv;
    reg [2:0] best_au, best_av;
    reg [2:0] diam1, diam2;
    reg [2:0] rad1, rad2;
    reg [2:0] cand_diam;
    reg [2:0] center1, center2;
    reg [2:0] bfs_start;
    reg [2:0] bfs_node;
    reg [2:0] dist [0:7];
    reg [7:0] visited;
    reg [2:0] queue [0:7];
    reg [3:0] q_head, q_tail;
    reg [2:0] max_dist;
    reg [2:0] farthest;
    reg [1:0] bfs_phase;
    reg [2:0] calc_node;
    reg [2:0] calc_sum;
    reg [2:0] best_comp_nodes;
    reg [2:0] comp_nodes;
    reg [3:0] cycle_count;

    // Helper function to get bit from packed matrix
    function [0:0] get_bit(input [63:0] mat, input [2:0] i, input [2:0] j);
        begin
            get_bit = mat[(i << 3) + j];
        end
    endfunction

    // Helper function to set bit in matrix
    function [63:0] set_bit(input [63:0] mat, input [2:0] i, input [2:0] j, input val);
        reg [5:0] idx;
        begin
            idx = (i << 3) + j;
            set_bit = mat;
            if (val)
                set_bit[idx] = 1'b1;
            else
                set_bit[idx] = 1'b0;
        end
    endfunction

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = INIT;
            INIT: next_state = FIND_EDGE;
            FIND_EDGE: begin
                if (edge_u < 3'd8 && edge_v < 3'd8) begin
                    if (get_bit(adj_reg, edge_u, edge_v) && edge_u != edge_v)
                        next_state = REMOVE_EDGE;
                    else
                        next_state = FIND_EDGE;
                end else begin
                    next_state = DONE_STATE;
                end
            end
            REMOVE_EDGE: next_state = BFS_COMP1;
            BFS_COMP1: next_state = BFS_DIST;
            BFS_COMP2: next_state = BFS_DIST;
            BFS_DIST: begin
                if (q_head != q_tail)
                    next_state = BFS_DIST;
                else if (bfs_phase == 2'd1)
                    next_state = BFS_COMP2;
                else
                    next_state = CALC_RADIUS;
            end
            CALC_RADIUS: begin
                if (comp_nodes > 3'd0)
                    next_state = CALC_RADIUS;
                else if (bfs_phase == 2'd1)
                    next_state = CALC_CAND;
                else
                    next_state = CALC_RADIUS;
            end
            CALC_CAND: next_state = UPDATE_BEST;
            UPDATE_BEST: next_state = RESTORE_EDGE;
            RESTORE_EDGE: next_state = FIND_EDGE;
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_diameter <= 3'd0;
            remove_u <= 3'd0;
            remove_v <= 3'd0;
            add_u <= 3'd0;
            add_v <= 3'd0;
            adj_reg <= 64'd0;
            temp_adj <= 64'd0;
            edge_u <= 3'd0;
            edge_v <= 3'd1;
            best_diam <= 3'd7;
            best_ru <= 3'd0;
            best_rv <= 3'd0;
            best_au <= 3'd0;
            best_av <= 3'd0;
            diam1 <= 3'd0;
            diam2 <= 3'd0;
            rad1 <= 3'd0;
            rad2 <= 3'd0;
            center1 <= 3'd0;
            center2 <= 3'd0;
            bfs_start <= 3'd0;
            bfs_node <= 3'd0;
            visited <= 8'd0;
            q_head <= 4'd0;
            q_tail <= 4'd0;
            max_dist <= 3'd0;
            farthest <= 3'd0;
            bfs_phase <= 2'd0;
            calc_node <= 3'd0;
            calc_sum <= 3'd0;
            best_comp_nodes <= 3'd0;
            comp_nodes <= 3'd0;
            cycle_count <= 4'd0;
            // Initialize dist array
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                dist[i] <= 3'd0;
            end
            // Initialize queue
            for (i = 0; i < 8; i = i + 1) begin
                queue[i] <= 3'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                end
                
                INIT: begin
                    adj_reg <= adj_flat;
                    temp_adj <= adj_flat;
                    edge_u <= 3'd0;
                    edge_v <= 3'd1;
                    best_diam <= 3'd7;
                    best_ru <= 3'd0;
                    best_rv <= 3'd0;
                    best_au <= 3'd0;
                    best_av <= 3'd0;
                end
                
                FIND_EDGE: begin
                    // Skip invalid or same nodes
                    if (edge_u >= 3'd8 || (get_bit(adj_reg, edge_u, edge_v) == 1'b0)) begin
                        if (edge_v < 3'd7) begin
                            edge_v <= edge_v + 3'd1;
                        end else begin
                            edge_v <= edge_u + 3'd2;
                            edge_u <= edge_u + 3'd1;
                        end
                    end
                end
                
                REMOVE_EDGE: begin
                    temp_adj <= set_bit(temp_adj, edge_u, edge_v, 1'b0);
                    temp_adj <= set_bit(temp_adj, edge_v, edge_u, 1'b0);
                    bfs_phase <= 2'd1;
                    bfs_start <= edge_u;
                end
                
                BFS_COMP1: begin
                    visited <= 8'd0;
                    visited[edge_u] <= 1'b1;
                    dist[edge_u] <= 3'd0;
                    queue[0] <= edge_u;
                    q_head <= 4'd0;
                    q_tail <= 4'd1;
                    max_dist <= 3'd0;
                    farthest <= edge_u;
                    comp_nodes <= 3'd1;
                end
                
                BFS_COMP2: begin
                    visited <= 8'd0;
                    visited[edge_v] <= 1'b1;
                    dist[edge_v] <= 3'd0;
                    queue[0] <= edge_v;
                    q_head <= 4'd0;
                    q_tail <= 4'd1;
                    max_dist <= 3'd0;
                    farthest <= edge_v;
                    comp_nodes <= 3'd1;
                end
                
                BFS_DIST: begin
                    if (q_head != q_tail) begin
                        bfs_node <= queue[q_head];
                        q_head <= q_head + 4'd1;
                    end else if (bfs_phase == 2'd1) begin
                        diam1 <= max_dist;
                        bfs_start <= farthest;
                        bfs_phase <= 2'd2;
                    end else begin
                        diam2 <= max_dist;
                        bfs_phase <= 2'd0;
                    end
                end
                
                CALC_RADIUS: begin
                    // Update max_dist and farthest based on neighbor exploration
                    // This is simplified - in real implementation would need
                    // separate state to process each neighbor
                    if (comp_nodes > 3'd0 && calc_node < 3'd8) begin
                        calc_node <= calc_node + 3'd1;
                    end else begin
                        calc_node <= 3'd0;
                        if (bfs_phase == 2'd1) begin
                            rad1 <= (max_dist + 3'd1) >> 1;
                            center1 <= farthest;
                            bfs_phase <= 2'd2;
                        end else begin
                            rad2 <= (max_dist + 3'd1) >> 1;
                            center2 <= farthest;
                        end
                    end
                end
                
                CALC_CAND: begin
                    cand_diam <= (diam1 > diam2) ? diam1 : diam2;
                    calc_sum <= rad1 + rad2 + 3'd1;
                    if (calc_sum > cand_diam)
                        cand_diam <= calc_sum;
                end
                
                UPDATE_BEST: begin
                    if (cand_diam < best_diam) begin
                        best_diam <= cand_diam;
                        best_ru <= edge_u;
                        best_rv <= edge_v;
                        best_au <= center1;
                        best_av <= center2;
                    end
                end
                
                RESTORE_EDGE: begin
                    temp_adj <= set_bit(temp_adj, edge_u, edge_v, 1'b1);
                    temp_adj <= set_bit(temp_adj, edge_v, edge_u, 1'b1);
                    cycle_count <= cycle_count + 4'd1;
                end
                
                DONE_STATE: begin
                    min_diameter <= best_diam;
                    remove_u <= best_ru;
                    remove_v <= best_rv;
                    add_u <= best_au;
                    add_v <= best_av;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule