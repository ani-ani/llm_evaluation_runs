module ginger_candies #(
    parameter MAX_N = 8,
    parameter MAX_M = 16,
    parameter C_WIDTH = 16,
    parameter RESULT_WIDTH = 32,
    parameter ALPHA_WIDTH = 5
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] M,
    input wire [2:0] u [0:MAX_M-1],
    input wire [2:0] v [0:MAX_M-1],
    input wire [C_WIDTH-1:0] c [0:MAX_M-1],
    input wire [MAX_M-1:0] valid_edge,
    input wire [ALPHA_WIDTH-1:0] alpha,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] LOAD       = 4'd1;
    localparam [3:0] ENUM_INIT  = 4'd2;
    localparam [3:0] ENUM_CHECK = 4'd3;
    localparam [3:0] CONN_CHECK = 4'd4;
    localparam [3:0] UPDATE_MIN = 4'd5;
    localparam [3:0] ENUM_NEXT  = 4'd6;
    localparam [3:0] DONE_STATE = 4'd7;
    
    reg [3:0] state, next_state;
    
    // Internal registers
    reg [3:0] M_reg;
    reg [2:0] u_reg [0:MAX_M-1];
    reg [2:0] v_reg [0:MAX_M-1];
    reg [C_WIDTH-1:0] c_reg [0:MAX_M-1];
    reg [MAX_M-1:0] valid_edge_reg;
    reg [ALPHA_WIDTH-1:0] alpha_reg;
    
    reg [MAX_M-1:0] subset_reg;
    reg [RESULT_WIDTH-1:0] min_cost;
    reg [3:0] edge_idx;
    reg [3:0] vertex_deg [0:MAX_N-1];
    reg [C_WIDTH-1:0] max_candy;
    reg [4:0] edge_count;
    
    // Connectivity check variables
    reg [MAX_N-1:0] visited;
    reg [2:0] queue [0:MAX_N-1];
    reg [2:0] queue_wr_ptr;
    reg [2:0] queue_rd_ptr;
    reg [2:0] current_vertex;
    reg [3:0] bfs_steps;
    reg connected;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= {RESULT_WIDTH{1'b1}};
            min_cost <= {RESULT_WIDTH{1'b1}};
            subset_reg <= {MAX_M{1'b0}};
            edge_idx <= 4'd0;
            max_candy <= {C_WIDTH{1'b0}};
            edge_count <= 5'd0;
            visited <= {MAX_N{1'b0}};
            queue_wr_ptr <= 3'd0;
            queue_rd_ptr <= 3'd0;
            bfs_steps <= 4'd0;
            connected <= 1'b0;
            
            for (i = 0; i < MAX_N; i = i + 1) begin
                vertex_deg[i] <= 4'd0;
            end
            for (i = 0; i < MAX_N; i = i + 1) begin
                queue[i] <= 3'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        M_reg <= M;
                        valid_edge_reg <= valid_edge;
                        alpha_reg <= alpha;
                        for (i = 0; i < MAX_M; i = i + 1) begin
                            u_reg[i] <= u[i];
                            v_reg[i] <= v[i];
                            c_reg[i] <= c[i];
                        end
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                LOAD: begin
                    subset_reg <= {{(MAX_M-1){1'b0}}, 1'b1};
                    min_cost <= {RESULT_WIDTH{1'b1}};
                    next_state <= ENUM_INIT;
                end
                
                ENUM_INIT: begin
                    edge_idx <= 4'd0;
                    max_candy <= {C_WIDTH{1'b0}};
                    edge_count <= 5'd0;
                    for (i = 0; i < MAX_N; i = i + 1) begin
                        vertex_deg[i] <= 4'd0;
                    end
                    connected <= 1'b0;
                    next_state <= ENUM_CHECK;
                end
                
                ENUM_CHECK: begin
                    if (edge_idx < M_reg) begin
                        if (subset_reg[edge_idx] && valid_edge_reg[edge_idx]) begin
                            vertex_deg[u_reg[edge_idx]] <= vertex_deg[u_reg[edge_idx]] + 4'd1;
                            vertex_deg[v_reg[edge_idx]] <= vertex_deg[v_reg[edge_idx]] + 4'd1;
                            
                            if (c_reg[edge_idx] > max_candy) begin
                                max_candy <= c_reg[edge_idx];
                            end
                            
                            edge_count <= edge_count + 5'd1;
                        end
                        edge_idx <= edge_idx + 4'd1;
                        next_state <= ENUM_CHECK;
                    end else begin
                        if (edge_count == 5'd0 || (edge_count & 5'd1)) begin
                            next_state <= ENUM_NEXT;
                        end else begin
                            // Check if all degrees are even
                            reg all_even;
                            all_even = 1'b1;
                            for (i = 0; i < MAX_N; i = i + 1) begin
                                if (vertex_deg[i][0]) begin
                                    all_even = 1'b0;
                                end
                            end
                            if (!all_even) begin
                                next_state <= ENUM_NEXT;
                            end else begin
                                // Find first vertex with degree >0
                                for (i = 0; i < MAX_N; i = i + 1) begin
                                    if (vertex_deg[i] > 4'd0) begin
                                        current_vertex = i;
                                        i = MAX_N; // Exit loop
                                    end
                                end
                                visited <= {MAX_N{1'b0}};
                                queue[0] <= current_vertex;
                                queue_wr_ptr <= 3'd1;
                                queue_rd_ptr <= 3'd0;
                                visited[current_vertex] <= 1'b1;
                                bfs_steps <= 4'd0;
                                next_state <= CONN_CHECK;
                            end
                        end
                    end
                end
                
                CONN_CHECK: begin
                    if (bfs_steps < edge_count) begin
                        if (queue_rd_ptr != queue_wr_ptr) begin
                            current_vertex = queue[queue_rd_ptr];
                            queue_rd_ptr <= queue_rd_ptr + 3'd1;
                            
                            for (i = 0; i < M_reg; i = i + 1) begin
                                if (subset_reg[i] && valid_edge_reg[i]) begin
                                    if (u_reg[i] == current_vertex && !visited[v_reg[i]]) begin
                                        queue[queue_wr_ptr] <= v_reg[i];
                                        queue_wr_ptr <= queue_wr_ptr + 3'd1;
                                        visited[v_reg[i]] <= 1'b1;
                                    end else if (v_reg[i] == current_vertex && !visited[u_reg[i]]) begin
                                        queue[queue_wr_ptr] <= u_reg[i];
                                        queue_wr_ptr <= queue_wr_ptr + 3'd1;
                                        visited[u_reg[i]] <= 1'b1;
                                    end
                                end
                            end
                            
                            bfs_steps <= bfs_steps + 4'd1;
                            next_state <= CONN_CHECK;
                        end else begin
                            // Queue empty
                            reg all_visited;
                            all_visited = 1'b1;
                            for (i = 0; i < MAX_N; i = i + 1) begin
                                if (vertex_deg[i] > 4'd0 && !visited[i]) begin
                                    all_visited = 1'b0;
                                end
                            end
                            connected <= all_visited;
                            next_state <= UPDATE_MIN;
                        end
                    end else begin
                        connected <= 1'b1;
                        next_state <= UPDATE_MIN;
                    end
                end
                
                UPDATE_MIN: begin
                    if (connected && (max_candy * max_candy + alpha_reg * edge_count) < min_cost) begin
                        min_cost <= max_candy * max_candy + alpha_reg * edge_count;
                    end
                    next_state <= ENUM_NEXT;
                end
                
                ENUM_NEXT: begin
                    if (subset_reg == {MAX_M{1'b1}}) begin
                        next_state <= DONE_STATE;
                    end else begin
                        subset_reg <= subset_reg + {{(MAX_M-1){1'b0}}, 1'b1};
                        next_state <= ENUM_INIT;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    result <= min_cost;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule