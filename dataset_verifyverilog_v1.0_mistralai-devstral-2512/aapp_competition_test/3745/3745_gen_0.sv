module GraphStringReconstruction(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [6:0] m,
    input [3:0] u_arr [0:15],
    input [3:0] v_arr [0:15],
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_EDGES = 3'd1;
    localparam [2:0] SOLVE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Adjacency matrix
    reg [15:0] adj_matrix [0:15];
    integer i, j, k;

    // BFS variables
    reg [3:0] current_vertex;
    reg [1:0] color [0:15];
    reg [3:0] stack_ptr;
    reg [3:0] stack [0:15];
    reg [1:0] stack_color [0:15];
    reg found;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize adjacency matrix
            for (i = 0; i < 16; i = i + 1) begin
                adj_matrix[i] <= 16'd0;
            end
            
            // Initialize BFS variables
            current_vertex <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                color[i] <= 2'd0;
            end
            stack_ptr <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                stack[i] <= 4'd0;
                stack_color[i] <= 2'd0;
            end
            found <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD_EDGES;
                    end
                end
                
                LOAD_EDGES: begin
                    // Load edges into adjacency matrix
                    for (i = 0; i < m; i = i + 1) begin
                        adj_matrix[u_arr[i]][v_arr[i]] <= 1'b1;
                        adj_matrix[v_arr[i]][u_arr[i]] <= 1'b1;
                    end
                    state <= SOLVE;
                end
                
                SOLVE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // BFS-based 3-coloring
                    if (!found) begin
                        if (stack_ptr == 0) begin
                            // Start with vertex 0
                            stack[0] <= 4'd0;
                            stack_color[0] <= 2'd0;
                            stack_ptr <= 4'd1;
                        end else begin
                            // Pop from stack
                            current_vertex <= stack[stack_ptr - 1];
                            color[current_vertex] <= stack_color[stack_ptr - 1];
                            stack_ptr <= stack_ptr - 1;
                            
                            // Check if all vertices are colored
                            if (current_vertex == n - 1) begin
                                found <= 1'b1;
                            end else begin
                                // Try next vertex
                                current_vertex <= current_vertex + 4'd1;
                                
                                // Try colors 'a', 'b', 'c'
                                for (k = 0; k < 3; k = k + 1) begin
                                    reg valid;
                                    integer l;
                                    
                                    valid <= 1'b1;
                                    for (l = 0; l < current_vertex; l = l + 1) begin
                                        if (adj_matrix[current_vertex][l]) begin
                                            if (color[l] != k && (color[l] != k + 1 && color[l] != k - 1)) begin
                                                valid <= 1'b0;
                                            end
                                        end
                                    end
                                    
                                    if (valid) begin
                                        stack[stack_ptr] <= current_vertex;
                                        stack_color[stack_ptr] <= k;
                                        stack_ptr <= stack_ptr + 1;
                                    end
                                end
                            end
                        end
                    end
                    
                    if (found || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    if (found) begin
                        result[31] <= 1'b1;
                        for (i = 0; i < n; i = i + 1) begin
                            result[2*i + 1:2*i] <= color[i];
                        end
                    end else begin
                        result[31] <= 1'b0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule