module vertex_deletion_maxflow(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [3:0] M,
    input [15:0] A [0:15],
    input [15:0] B [0:15],
    input [3:0] edge_u [0:15],
    input [3:0] edge_v [0:15],
    output reg [31:0] profit,
    output reg done
);

    // Constants
    localparam [5:0] SOURCE = 6'd0;
    localparam [5:0] SINK = 6'd1;
    localparam [5:0] MAX_NODES = 6'd34;
    localparam [31:0] INF = 32'd2147483647;

    // State machine
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] BFS = 3'd2;
    localparam [2:0] DFS = 3'd3;
    localparam [2:0] COMPUTE = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd900;

    // Graph data structures
    reg [31:0] capacity [0:MAX_NODES-1][0:MAX_NODES-1];
    reg [31:0] flow [0:MAX_NODES-1][0:MAX_NODES-1];
    reg [31:0] residual [0:MAX_NODES-1][0:MAX_NODES-1];

    // BFS/DFS variables
    reg [5:0] level [0:MAX_NODES-1];
    reg [5:0] ptr [0:MAX_NODES-1];
    reg [5:0] queue [0:MAX_NODES-1];
    reg [5:0] q_head, q_tail;
    reg [5:0] current_node;
    reg [31:0] min_capacity;
    reg [5:0] stack [0:MAX_NODES-1];
    reg [5:0] stack_ptr;

    // Flow variables
    reg [31:0] max_flow;
    reg [31:0] total_B;

    // Initialize graph
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            profit <= 32'd0;
            max_flow <= 32'd0;
            total_B <= 32'd0;
            cycle_count <= 8'd0;

            // Initialize all arrays
            for (i = 0; i < MAX_NODES; i = i + 1) begin
                for (j = 0; j < MAX_NODES; j = j + 1) begin
                    capacity[i][j] <= 32'd0;
                    flow[i][j] <= 32'd0;
                    residual[i][j] <= 32'd0;
                end
                level[i] <= 6'd0;
                ptr[i] <= 6'd0;
                queue[i] <= 6'd0;
            end
            q_head <= 6'd0;
            q_tail <= 6'd0;
            current_node <= 6'd0;
            min_capacity <= 32'd0;
            stack_ptr <= 6'd0;
            for (i = 0; i < MAX_NODES; i = i + 1) begin
                stack[i] <= 6'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Initialize graph structure
                    for (i = 0; i < MAX_NODES; i = i + 1) begin
                        for (j = 0; j < MAX_NODES; j = j + 1) begin
                            capacity[i][j] <= 32'd0;
                            flow[i][j] <= 32'd0;
                            residual[i][j] <= 32'd0;
                        end
                    end

                    // Add source/sink connections
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < N) begin
                            // Source to i_in (node 2 + 2*i)
                            capacity[SOURCE][2 + 2*i] <= (B[i][15] ? -B[i][15:0] : B[i][15:0]);
                            
                            // i_in to i_out (node 2 + 2*i to 3 + 2*i)
                            capacity[2 + 2*i][3 + 2*i] <= A[i][15:0];
                            
                            // i_out to sink (node 3 + 2*i)
                            capacity[3 + 2*i][SINK] <= (B[i][15] ? B[i][15:0] : -B[i][15:0]);
                            
                            // Accumulate total |B_i|
                            total_B <= total_B + (B[i][15] ? -B[i][15:0] : B[i][15:0]);
                        end
                    end

                    // Add graph edges
                    for (i = 0; i < M; i = i + 1) begin
                        if (i < M) begin
                            reg [5:0] u_out = 3 + 2*edge_u[i];
                            reg [5:0] v_in = 2 + 2*edge_v[i];
                            reg [5:0] v_out = 3 + 2*edge_v[i];
                            reg [5:0] u_in = 2 + 2*edge_u[i];
                            
                            capacity[u_out][v_in] <= INF;
                            capacity[v_out][u_in] <= INF;
                        end
                    end

                    // Initialize residual graph
                    for (i = 0; i < MAX_NODES; i = i + 1) begin
                        for (j = 0; j < MAX_NODES; j = j + 1) begin
                            residual[i][j] <= capacity[i][j];
                        end
                    end

                    next_state <= BFS;
                end

                BFS: begin
                    // BFS to build level graph
                    for (i = 0; i < MAX_NODES; i = i + 1) begin
                        level[i] <= 6'd33; // Initialize to "infinity"
                    end
                    level[SOURCE] <= 6'd0;
                    q_head <= 6'd0;
                    q_tail <= 6'd1;
                    queue[0] <= SOURCE;

                    // BFS loop
                    reg [5:0] q_size = q_tail - q_head;
                    if (q_size > 0) begin
                        current_node <= queue[q_head];
                        q_head <= q_head + 6'd1;

                        for (i = 0; i < MAX_NODES; i = i + 1) begin
                            if (residual[current_node][i] > 0 && level[i] == 6'd33) begin
                                level[i] <= level[current_node] + 6'd1;
                                queue[q_tail] <= i;
                                q_tail <= q_tail + 6'd1;
                            end
                        end
                    end

                    // Check if sink reached
                    if (level[SINK] != 6'd33) begin
                        // Reset pointers
                        for (i = 0; i < MAX_NODES; i = i + 1) begin
                            ptr[i] <= 6'd0;
                        end
                        next_state <= DFS;
                    end else begin
                        next_state <= COMPUTE;
                    end
                end

                DFS: begin
                    // DFS to find blocking flow
                    stack_ptr <= 6'd0;
                    stack[0] <= SOURCE;
                    min_capacity <= INF;
                    current_node <= SOURCE;

                    // DFS loop
                    reg found_path = 1'b0;
                    reg [5:0] next_node;
                    
                    for (i = ptr[current_node]; i < MAX_NODES; i = i + 1) begin
                        if (residual[current_node][i] > 0 && 
                            level[i] == level[current_node] + 6'd1) begin
                            ptr[current_node] <= i + 6'd1;
                            
                            if (i == SINK) begin
                                // Found path to sink
                                found_path <= 1'b1;
                                // Update flow along path
                                reg [5:0] path_node;
                                reg [31:0] flow_to_add = min_capacity;
                                
                                for (j = 0; j < stack_ptr; j = j + 1) begin
                                    path_node <= stack[j];
                                    // Update residual graph
                                    residual[path_node][stack[j+1]] <= residual[path_node][stack[j+1]] - flow_to_add;
                                    residual[stack[j+1]][path_node] <= residual[stack[j+1]][path_node] + flow_to_add;
                                    
                                    // Update flow
                                    flow[path_node][stack[j+1]] <= flow[path_node][stack[j+1]] + flow_to_add;
                                end
                                
                                max_flow <= max_flow + flow_to_add;
                                next_state <= BFS;
                            end else begin
                                // Push to stack
                                stack_ptr <= stack_ptr + 6'd1;
                                stack[stack_ptr] <= i;
                                current_node <= i;
                                
                                // Update min capacity
                                if (residual[current_node][i] < min_capacity) begin
                                    min_capacity <= residual[current_node][i];
                                end
                            end
                            break;
                        end
                    end

                    if (!found_path) begin
                        next_state <= BFS;
                    end
                end

                COMPUTE: begin
                    // Compute profit
                    profit <= total_B - max_flow;
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule