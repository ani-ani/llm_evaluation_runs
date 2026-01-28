module MinimumDebt(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [3:0] debt_to [0:15],
    input wire [15:0] debt_amt [0:15],
    output reg [15:0] result,
    output reg done
);
    // State definitions
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] INIT       = 4'd1;
    localparam [3:0] CYCLE_FIND = 4'd2;
    localparam [3:0] COMPUTE    = 4'd3;
    localparam [3:0] DONE_STATE = 4'd4;
    
    reg [3:0] state;
    reg [3:0] next_state;
    
    // Node index counter (0 to N-1)
    reg [3:0] node_idx;
    reg [3:0] next_node_idx;
    
    // For cycle detection using Floyd's algorithm (or iterative DFS)
    // Using visited array to track processed nodes
    reg [15:0] visited; // 16 bits for 16 nodes
    reg [15:0] visited_next;
    
    // For tracking current path/sequence
    reg [3:0] current_node;
    reg [3:0] next_current_node;
    reg [3:0] step_count;
    reg [3:0] step_count_next;
    
    // For finding minimum in current cycle
    reg [15:0] cycle_min;
    reg [15:0] next_cycle_min;
    
    // Accumulator for total result
    reg [15:0] total_sum;
    reg [15:0] next_total_sum;
    
    // Temp storage for cycle traversal
    reg [3:0] walker;
    reg [3:0] next_walker;
    
    // Cycle detection logic
    reg found_cycle;
    reg [3:0] cycle_start_node;
    
    // Registers for outputs
    reg [15:0] result_reg;
    reg done_reg;
    
    integer i;
    
    // State transition and register updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            node_idx <= 4'd0;
            visited <= 16'd0;
            current_node <= 4'd0;
            step_count <= 4'd0;
            cycle_min <= 16'hFFFF;
            total_sum <= 16'd0;
            walker <= 4'd0;
            result_reg <= 16'd0;
            done_reg <= 1'b0;
        end else begin
            state <= next_state;
            node_idx <= next_node_idx;
            visited <= visited_next;
            current_node <= next_current_node;
            step_count <= step_count_next;
            cycle_min <= next_cycle_min;
            total_sum <= next_total_sum;
            walker <= next_walker;
            result_reg <= (state == DONE_STATE) ? total_sum : result_reg;
            done_reg <= (state == DONE_STATE) ? 1'b1 : 1'b0;
        end
    end
    
    // Output assignment
    always @(*) begin
        result = result_reg;
        done = done_reg;
    end
    
    // Combinational next state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_node_idx = node_idx;
        next_visited = visited;
        next_current_node = current_node;
        next_step_count = step_count;
        next_cycle_min = cycle_min;
        next_total_sum = total_sum;
        next_walker = walker;
        
        found_cycle = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                    next_node_idx = 4'd0;
                    next_visited = 16'd0;
                    next_total_sum = 16'd0;
                    next_done_reg = 1'b0;
                end
            end
            
            INIT: begin
                // Skip already visited nodes
                if (node_idx >= N) begin
                    next_state = DONE_STATE;
                end else if (visited[node_idx]) begin
                    // Move to next node
                    if (node_idx + 1 < N) begin
                        next_node_idx = node_idx + 1;
                    end else begin
                        next_state = DONE_STATE;
                    end
                end else begin
                    // Found new unvisited node, start cycle detection
                    next_state = CYCLE_FIND;
                    next_current_node = node_idx;
                    next_walker = node_idx;
                    next_cycle_min = 16'hFFFF;
                    next_step_count = 4'd0;
                    next_visited[node_idx] = 1'b1;
                end
            end
            
            CYCLE_FIND: begin
                // Floyd's cycle finding or simple iteration
                // Since N is small (16), we can iterate 16 steps max
                if (step_count >= N) begin
                    // No cycle found from this start node (shouldn't happen in functional graph)
                    next_state = INIT;
                    if (node_idx + 1 < N) begin
                        next_node_idx = node_idx + 1;
                    end else begin
                        next_state = DONE_STATE;
                    end
                end else begin
                    // Move forward one step
                    next_walker = debt_to[walker];
                    next_step_count = step_count + 1;
                    
                    // Check if we closed a cycle
                    // Simple approach: if walker returns to start of cycle
                    // But we need to detect when cycle is fully traced
                    
                    // Better approach: track minimum as we traverse
                    // The cycle is complete when we reach a node already in this cycle
                    // Use visited bits for cycle membership (temporarily)
                    
                    if (walker == current_node && step_count > 0) begin
                        // Closed a loop
                        // Current debt is the edge we just traversed
                        // But we need to check all edges in cycle
                        // Let's just continue to compute min and sum
                    end
                    
                    // Find min in this traversal
                    if (debt_amt[walker] < next_cycle_min) begin
                        next_cycle_min = debt_amt[walker];
                    end
                    
                    // Check if we've completed the cycle
                    // We complete when we see a node we've already visited in THIS cycle
                    // For simplicity, since graph is functional, we can detect when
                    // walker == current_node after at least 1 step
                    
                    if (walker == current_node && step_count > 0) begin
                        found_cycle = 1'b1;
                        next_state = COMPUTE;
                    end
                end
            end
            
            COMPUTE: begin
                // Add minimum of found cycle to total
                next_total_sum = total_sum + cycle_min;
                next_state = INIT;
                
                // Move to next node to check
                if (node_idx + 1 < N) begin
                    next_node_idx = node_idx + 1;
                end else begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                // Done pulse already set in sequential block
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule