module PathFinder(
    input clk,
    input rst_n,
    input start,
    input [3:0] node_count,
    input [3:0] labels [0:15],
    input adj_matrix [0:15][0:15],
    output reg [3:0] path [0:8],
    output reg done,
    output reg found
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SEARCH = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [13:0] cycle_count;
    localparam [13:0] MAX_CYCLES = 14'd10000;

    // Search state
    reg [3:0] current_path [0:8];
    reg [3:0] current_depth;
    reg [15:0] visited_labels;
    reg [3:0] current_node;
    reg [3:0] next_node;
    reg [3:0] stack_ptr;
    reg [3:0] stack [0:15];
    reg [15:0] stack_visited [0:15];
    reg [3:0] stack_depth [0:15];
    reg [3:0] stack_path [0:15][0:8];

    // Initialize all registers
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            found <= 1'b0;
            cycle_count <= 14'd0;
            current_depth <= 4'd0;
            visited_labels <= 16'd0;
            current_node <= 4'd0;
            next_node <= 4'd0;
            stack_ptr <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                stack[i] <= 4'd0;
                stack_visited[i] <= 16'd0;
                stack_depth[i] <= 4'd0;
                for (j = 0; j < 9; j = j + 1) begin
                    stack_path[i][j] <= 4'd0;
                end
            end
            for (i = 0; i < 9; i = i + 1) begin
                current_path[i] <= 4'd0;
                path[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 14'd0;
                    if (start) begin
                        state <= SEARCH;
                        // Initialize search
                        current_depth <= 4'd0;
                        visited_labels <= 16'd0;
                        current_node <= 4'd0;
                        stack_ptr <= 4'd0;
                        for (i = 0; i < 9; i = i + 1) begin
                            current_path[i] <= 4'd0;
                        end
                    end
                end
                
                SEARCH: begin
                    cycle_count <= cycle_count + 14'd1;
                    
                    // Check if we've found a path
                    if (current_depth == 4'd9) begin
                        found <= 1'b1;
                        for (i = 0; i < 9; i = i + 1) begin
                            path[i] <= current_path[i];
                        end
                        state <= FINISH;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        found <= 1'b0;
                        state <= FINISH;
                    end else begin
                        // Try to find next node
                        reg [3:0] candidate;
                        reg found_candidate;
                        found_candidate = 1'b0;
                        
                        for (candidate = 0; candidate < node_count; candidate = candidate + 1) begin
                            if (adj_matrix[current_node][candidate] && 
                                !(visited_labels[labels[candidate]]) && 
                                !found_candidate) begin
                                found_candidate = 1'b1;
                                next_node <= candidate;
                            end
                        end
                        
                        if (found_candidate) begin
                            // Push current state to stack
                            stack[stack_ptr] <= current_node;
                            stack_visited[stack_ptr] <= visited_labels;
                            stack_depth[stack_ptr] <= current_depth;
                            for (i = 0; i < 9; i = i + 1) begin
                                stack_path[stack_ptr][i] <= current_path[i];
                            end
                            stack_ptr <= stack_ptr + 4'd1;
                            
                            // Update current state
                            current_path[current_depth] <= next_node;
                            visited_labels[labels[next_node]] <= 1'b1;
                            current_node <= next_node;
                            current_depth <= current_depth + 4'd1;
                        end else if (stack_ptr > 4'd0) begin
                            // Backtrack
                            stack_ptr <= stack_ptr - 4'd1;
                            current_node <= stack[stack_ptr];
                            visited_labels <= stack_visited[stack_ptr];
                            current_depth <= stack_depth[stack_ptr];
                            for (i = 0; i < 9; i = i + 1) begin
                                current_path[i] <= stack_path[stack_ptr][i];
                            end
                        end else begin
                            // No path found
                            found <= 1'b0;
                            state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule