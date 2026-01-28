module NetworkFlowOptimizer #(
    parameter MAX_NODES = 16,
    parameter MAX_PIPES = 16,
    parameter FIXED_WIDTH = 32
) (
    input clk,
    input rst_n,
    input start,
    
    input [4:0] src_idx [0:15],      // Source node for each pipe
    input [4:0] dst_idx [0:15],      // Destination node for each pipe
    input [FIXED_WIDTH-1:0] capacity [0:15],  // Pipe capacity C
    input [FIXED_WIDTH-1:0] viscosity,         // Flubber viscosity v
    input [FIXED_WIDTH-1:0] weight_a,          // Objective weight a (Q16.16)
    
    output reg [FIXED_WIDTH-1:0] f_flubber [0:15],  // Flubber flow per pipe
    output reg [FIXED_WIDTH-1:0] f_water [0:15],    // Water flow per pipe
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] FIND_PATH = 3'd2;
    localparam [2:0] AUGMENT = 3'd3;
    localparam [2:0] UPDATE_OBJ = 3'd4;
    localparam [2:0] COMPLETE = 3'd5;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Internal registers
    reg [7:0] iter_count;
    reg [4:0] src_node;
    reg [4:0] dst_node;
    reg [4:0] current_pipe;
    reg [31:0] best_objective;
    reg [31:0] current_objective;
    reg [7:0] q_count;
    reg [7:0] q_ptr;
    reg [7:0] visited_ptr;
    reg [4:0] path_stack [0:15];
    reg [7:0] stack_ptr;
    reg path_found;
    
    // Queue for BFS (stores node indices)
    reg [4:0] bfs_queue [0:15];
    reg [4:0] prev_node [0:16];  // Previous node in path
    reg [4:0] prev_pipe [0:16];  // Previous pipe used
    reg visited [0:15];
    
    // Fixed-point constants
    localparam [31:0] ONE = 32'h0001_0000;  // 1.0 in Q16.16
    localparam [31:0] TWO = 32'h0002_0000;  // 2.0 in Q16.16
    localparam [31:0] HALF = 32'h0000_8000; // 0.5 in Q16.16
    
    // Temporary storage for augmenting
    reg [31:0] aug_flubber;
    reg [31:0] aug_water;
    reg [31:0] aug_capacity;
    
    integer i;
    
    // Combinational logic: simple multiplication for fixed-point
    wire [63:0] mult_result;
    wire [31:0] mult_truncated;
    
    // Multiplier instance (simplified combinational)
    // In synthesis, would use proper DSP block
    assign mult_result = aug_flubber * viscosity;  // v*F
    assign mult_truncated = mult_result[47:16];     // Q16.16 result
    
    // Helper: Check if pipe can carry more flow (residual capacity > 0)
    // residual = C - (v*F + W)
    wire [31:0] current_usage;
    wire [31:0] residual;
    wire can_use;
    
    assign current_usage = mult_truncated + f_water[current_pipe];
    assign residual = capacity[current_pipe] - current_usage;
    assign can_use = (residual > 0) && 
                     ((f_flubber[current_pipe] == 0) || (f_water[current_pipe] == 0) ||
                      (current_pipe == 0)); // Allow new pipe or pipe with same direction
    
    // Helper: Calculate objective for current flows
    // obj = F^a * W^(1-a) - using fixed-point approximation
    // For simplicity, use multiplicative form: (F^a) * (W^(1-a))
    // Approximate powers via shift/multiply
    wire [63:0] obj_mult;
    wire [31:0] obj_result;
    wire [31:0] f_pow_a;
    wire [31:0] w_pow_1a;
    
    // Simplified power approximation using bit shifts
    // For Q16.16, F^a ≈ F >> (16 - a) for small a
    // This is a heuristic; real implementation needs better approximation
    assign f_pow_a = (f_flubber[current_pipe] >> (16 - weight_a[15:12]));
    assign w_pow_1a = (f_water[current_pipe] >> (weight_a[15:12]));
    assign obj_mult = f_pow_a * w_pow_1a;
    assign obj_result = obj_mult[47:16];  // Back to Q16.16
    
    // Combinational: Get flow direction for pipe
    function [0:0] is_same_direction;
        input [31:0] f1, f2;
        begin
            is_same_direction = (f1 == 0) || (f2 == 0) || 
                               ((f1[31] == f2[31]) && (f1 != 0) && (f2 != 0));
        end
    endfunction
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            iter_count <= 8'd0;
            done <= 1'b0;
            best_objective <= 32'd0;
            current_objective <= 32'd0;
            q_ptr <= 8'd0;
            q_count <= 8'd0;
            visited_ptr <= 8'd0;
            stack_ptr <= 8'd0;
            path_found <= 1'b0;
            
            // Initialize flow arrays to zero
            for (i = 0; i < 16; i = i + 1) begin
                f_flubber[i] <= 32'd0;
                f_water[i] <= 32'd0;
                visited[i] <= 1'b0;
                prev_node[i] <= 5'd0;
                prev_pipe[i] <= 5'd0;
                bfs_queue[i] <= 5'd0;
                path_stack[i] <= 5'd0;
            end
            
            prev_node[16] <= 5'd0;
            current_pipe <= 5'd0;
            src_node <= 5'd0;
            dst_node <= 5'd0;
            aug_flubber <= 32'd0;
            aug_water <= 32'd0;
            aug_capacity <= 32'd0;
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    iter_count <= 8'd0;
                    best_objective <= 32'd0;
                    
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Reset all flow to zero for new computation
                    for (i = 0; i < 16; i = i + 1) begin
                        f_flubber[i] <= 32'd0;
                        f_water[i] <= 32'd0;
                    end
                    iter_count <= 8'd0;
                    best_objective <= 32'd0;
                    state <= FIND_PATH;
                    cycle_count <= cycle_count + 8'd1;
                end
                
                FIND_PATH: begin
                    // Use BFS to find augmenting path from node 0 to node 15
                    // Reset BFS state
                    if (cycle_count == 8'd0) begin
                        // First time in this state
                        for (i = 0; i < 16; i = i + 1) begin
                            visited[i] <= 1'b0;
                            prev_node[i] <= 5'd0;
                            prev_pipe[i] <= 5'd0;
                        end
                        prev_node[16] <= 5'd0;
                        
                        // Initialize queue
                        visited[0] <= 1'b1;
                        bfs_queue[0] <= 5'd0;  // Start from node 0
                        q_ptr <= 8'd0;
                        q_count <= 8'd1;
                        path_found <= 1'b0;
                    end
                    
                    if (q_ptr < q_count && !path_found) begin
                        // Process queue
                        reg [4:0] current_node;
                        current_node = bfs_queue[q_ptr];
                        q_ptr <= q_ptr + 8'd1;
                        
                        if (current_node == 5'd15) begin  // Reached sink
                            path_found <= 1'b1;
                            dst_node <= current_node;
                        end else begin
                            // Explore adjacent pipes
                            // Check all pipes for connections from current_node
                            for (i = 0; i < 16; i = i + 1) begin
                                if (src_idx[i] == current_node && !visited[dst_idx[i]]) begin
                                    // Check residual capacity
                                    if (can_use) begin
                                        visited[dst_idx[i]] <= 1'b1;
                                        prev_node[dst_idx[i]] <= current_node;
                                        prev_pipe[dst_idx[i]] <= i[4:0];
                                        bfs_queue[q_count] <= dst_idx[i];
                                        q_count <= q_count + 8'd1;
                                        
                                        if (dst_idx[i] == 5'd15) begin
                                            path_found <= 1'b1;
                                            dst_node <= 5'd15;
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    // Transition conditions
                    if (path_found) begin
                        // Reconstruct path and calculate augment
                        state <= AUGMENT;
                        stack_ptr <= 8'd0;
                    end else if (q_ptr >= q_count || q_count >= 16) begin
                        // No more paths or queue full
                        if (iter_count > 8'd0) begin
                            state <= COMPLETE;
                        end else begin
                            state <= COMPLETE;
                        end
                    end
                    
                    cycle_count <= cycle_count + 8'd1;
                end
                
                AUGMENT: begin
                    // Reconstruct path and find bottleneck
                    if (stack_ptr == 8'd0) begin
                        // Start reconstruction
                        current_pipe <= prev_pipe[dst_node];
                        reg [4:0] temp_node;
                        temp_node = dst_node;
                        
                        // Find min residual along path
                        aug_capacity <= 32'h7FFF_FFFF;  // Large initial value
                        aug_flubber <= 32'd0;
                        aug_water <= 32'd0;
                        
                        // Store path in stack
                        stack_ptr <= 8'd1;
                        path_stack[0] <= dst_node;
                        
                        // Continue to next pipe
                        state <= AUGMENT;
                    end else if (stack_ptr < 16) begin
                        // Continue reconstruction
                        reg [4:0] node;
                        node = path_stack[stack_ptr - 8'd1];
                        
                        if (node != 5'd0) begin
                            reg [4:0] pipe_idx;
                            reg [4:0] prev;
                            
                            pipe_idx = prev_pipe[node];
                            prev = prev_node[node];
                            
                            // Update residual calculation for this pipe
                            // For augment, we add flow
                            // Find bottleneck
                            reg [31:0] pipe_residual;
                            reg [31:0] v_f;
                            v_f = (viscosity * f_flubber[pipe_idx]) >> 16;
                            pipe_residual = capacity[pipe_idx] - (v_f + f_water[pipe_idx]);
                            
                            if (pipe_residual < aug_capacity) begin
                                aug_capacity <= pipe_residual;
                            end
                            
                            path_stack[stack_ptr] <= prev;
                            stack_ptr <= stack_ptr + 8'd1;
                            state <= AUGMENT;
                        end else begin
                            // Reached source, apply augmentation
                            state <= UPDATE_OBJ;
                            stack_ptr <= 8'd0;
                            
                            // For optimal allocation: split bottleneck between F and W
                            // We want to maximize F^a * W^(1-a) subject to vF + W <= C
                            // Solution: W = C/(1+v), F = W/v (or proportional)
                            // For fixed a: F = (a*C)/(v), W = ((1-a)*C)/(1) ... simplified
                            // Using proportional split based on weight
                            aug_flubber <= (aug_capacity * weight_a) >> 16;
                            aug_water <= (aug_capacity * (ONE - weight_a)) >> 16;
                        end
                    end
                end
                
                UPDATE_OBJ: begin
                    // Apply augmentation to all pipes in path
                    if (stack_ptr == 8'd0) begin
                        // Start application
                        current_pipe <= prev_pipe[dst_node];
                        stack_ptr <= 8'd1;
                        path_stack[0] <= dst_node;
                    end else if (stack_ptr < 16) begin
                        reg [4:0] node;
                        node = path_stack[stack_ptr - 8'd1];
                        
                        if (node != 5'd0) begin
                            reg [4:0] pipe_idx;
                            reg [4:0] prev;
                            
                            pipe_idx = prev_pipe[node];
                            prev = prev_node[node];
                            
                            // Add flows
                            f_flubber[pipe_idx] <= f_flubber[pipe_idx] + aug_flubber;
                            f_water[pipe_idx] <= f_water[pipe_idx] + aug_water;
                            
                            path_stack[stack_ptr] <= prev;
                            stack_ptr <= stack_ptr + 8'd1;
                            state <= UPDATE_OBJ;
                        end else begin
                            // Path complete, calculate new objective
                            // Sum of (F^a * W^(1-a)) across all pipes
                            current_objective <= 32'd0;
                            current_pipe <= 5'd0;
                            state <= UPDATE_OBJ;
                            
                            // Reset for objective calculation
                            if (iter_count == 0) begin
                                best_objective <= 32'd0;
                            end
                        end
                    end else begin
                        // Calculate total objective
                        reg [31:0] total_obj;
                        total_obj = 32'd0;
                        
                        // Sum contributions from all pipes with flow
                        for (i = 0; i < 16; i = i + 1) begin
                            if (f_flubber[i] > 0 || f_water[i] > 0) begin
                                reg [63:0] obj_temp;
                                reg [31:0] f_norm, w_norm;
                                
                                // Normalize to avoid overflow
                                f_norm = f_flubber[i] >> 8;  // Scale down
                                w_norm = f_water[i] >> 8;
                                
                                obj_temp = (f_norm * w_norm);
                                total_obj = total_obj + (obj_temp >> 8);
                            end
                        end
                        
                        if (total_obj > best_objective) begin
                            best_objective <= total_obj;
                        end
                        
                        iter_count <= iter_count + 8'd1;
                        
                        // Check if we should continue
                        if (iter_count >= 8'd100) begin
                            state <= COMPLETE;
                        end else begin
                            state <= FIND_PATH;
                            cycle_count <= cycle_count + 8'd1;
                        end
                    end
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    // Stay in complete until start goes low
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Cycle guard to prevent infinite loops
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != COMPLETE) begin
                state <= COMPLETE;
            end
        end
    end
    
endmodule