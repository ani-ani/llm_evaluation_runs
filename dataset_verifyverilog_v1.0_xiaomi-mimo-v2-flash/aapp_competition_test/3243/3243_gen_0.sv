module GraphConnectivity (
    input clk,
    input rst_n,
    input start,
    input [3:0] n_in,
    input [3:0] k_in,
    input [3:0] edge_u_in,
    input [3:0] edge_v_in,
    input edge_valid_in,
    input [3:0] deg_in [0:15],
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LOAD     = 3'd1;
    localparam [2:0] COMPUTE  = 3'd2;
    localparam [2:0] DONE     = 3'd3;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] n_reg;
    reg [3:0] k_reg;
    reg [3:0] edge_count;
    reg [3:0] u_reg;
    reg [3:0] v_reg;
    reg valid_reg;
    
    // DSU Arrays (16 elements, 4 bits each)
    reg [3:0] parent [0:15];
    reg [3:0] rank   [0:15];
    reg [3:0] current_degree [0:15];
    
    // Computation registers
    reg [3:0] components;
    reg [3:0] violations;
    reg [3:0] total_edits;
    reg [3:0] result_temp;
    
    // DSU Helper Registers (for sequential Find/Union)
    reg [3:0] dsu_root;
    reg [3:0] dsu_find_idx;
    reg [3:0] dsu_union_u;
    reg [3:0] dsu_union_v;
    reg [3:0] temp_u;
    reg [3:0] temp_v;
    reg dsu_find_done;
    reg dsu_union_done;
    
    // Loop counters
    reg [4:0] i; // 0-16
    reg [4:0] j;
    reg [4:0] loop_count;
    
    // Internal flags
    reg edge_processed;
    
    integer idx;

    // Edge Buffer (16 edges, 8 bits each: 4+4)
    reg [7:0] edge_buf [0:15];
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Main FSM and Computation Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            done <= 1'b0;
            result <= 1'b0;
            n_reg <= 4'd0;
            k_reg <= 4'd0;
            edge_count <= 4'd0;
            u_reg <= 4'd0;
            v_reg <= 4'd0;
            valid_reg <= 1'b0;
            edge_processed <= 1'b0;
            components <= 4'd0;
            violations <= 4'd0;
            total_edits <= 4'd0;
            result_temp <= 4'd0;
            dsu_find_done <= 1'b0;
            dsu_union_done <= 1'b0;
            dsu_root <= 4'd0;
            dsu_find_idx <= 4'd0;
            dsu_union_u <= 4'd0;
            dsu_union_v <= 4'd0;
            temp_u <= 4'd0;
            temp_v <= 4'd0;
            i <= 5'd0;
            j <= 5'd0;
            loop_count <= 5'd0;
            
            for (idx = 0; idx < 16; idx = idx + 1) begin
                parent[idx] <= 4'd0;
                rank[idx] <= 4'd0;
                current_degree[idx] <= 4'd0;
                edge_buf[idx] <= 8'd0;
            end
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n_in;
                        k_reg <= k_in;
                        edge_count <= 4'd0;
                        edge_processed <= 1'b0;
                        // Initialize DSU parent to self
                        for (idx = 0; idx < 16; idx = idx + 1) begin
                            if (idx < n_in) begin
                                parent[idx] <= idx;
                            end else begin
                                parent[idx] <= 4'd15; // Invalid
                            end
                            rank[idx] <= 4'd0;
                            current_degree[idx] <= 4'd0;
                            edge_buf[idx] <= 8'd0;
                        end
                    end
                end
                
                LOAD: begin
                    valid_reg <= edge_valid_in;
                    u_reg <= edge_u_in;
                    v_reg <= edge_v_in;
                    
                    if (edge_valid_in && !edge_processed) begin
                        // Ensure u < v for canonical storage
                        if (edge_u_in < edge_v_in) begin
                            u_reg <= edge_u_in;
                            v_reg <= edge_v_in;
                        end else begin
                            u_reg <= edge_v_in;
                            v_reg <= edge_u_in;
                        end
                        
                        // Store edge if buffer not full
                        if (edge_count < n_reg) begin
                            if (edge_u_in < edge_v_in)
                                edge_buf[edge_count] <= {edge_v_in, edge_u_in};
                            else
                                edge_buf[edge_count] <= {edge_u_in, edge_v_in};
                            edge_count <= edge_count + 4'd1;
                            
                            // Update degree (only if node index is valid)
                            if (edge_u_in < n_reg && edge_v_in < n_reg) begin
                                current_degree[edge_u_in] <= current_degree[edge_u_in] + 4'd1;
                                current_degree[edge_v_in] <= current_degree[edge_v_in] + 4'd1;
                            end
                        end
                        edge_processed <= 1'b1;
                    end else if (!edge_valid_in) begin
                        edge_processed <= 1'b0;
                    end
                    
                    // Exit LOAD when external trigger implies done (simplified)
                    // For this design, we rely on a cycle limit or manual input stop
                    // Here, we transition if no valid input for 16 cycles (heuristic)
                end
                
                COMPUTE: begin
                    // Step 1: Union all edges (Iterative)
                    if (loop_count < edge_count) begin
                        // Get edge from buffer
                        dsu_union_u <= edge_buf[loop_count][3:0];
                        dsu_union_v <= edge_buf[loop_count][7:4];
                        
                        // Perform Find on U
                        temp_u <= dsu_union_u;
                        // Find Loop logic
                        if (parent[temp_u] != temp_u && parent[temp_u] < n_reg) begin
                            temp_u <= parent[temp_u];
                        end
                        // If root found (or invalid), proceed to V
                        if (parent[temp_u] == temp_u || parent[temp_u] >= n_reg) begin
                             // Now Find on V
                             temp_v <= dsu_union_v;
                             if (parent[temp_v] != temp_v && parent[temp_v] < n_reg) begin
                                 temp_v <= parent[temp_v];
                             end else begin
                                 // Both roots found, perform Union
                                 if (temp_u != temp_v && temp_u < n_reg && temp_v < n_reg) begin
                                     if (rank[temp_u] < rank[temp_v]) begin
                                         parent[temp_u] <= temp_v;
                                     end else if (rank[temp_u] > rank[temp_v]) begin
                                         parent[temp_v] <= temp_u;
                                     end else begin
                                         parent[temp_v] <= temp_u;
                                         rank[temp_u] <= rank[temp_u] + 4'd1;
                                     end
                                 end
                                 loop_count <= loop_count + 5'd1;
                             end
                        end
                    end else if (loop_count == edge_count && i < n_reg) begin
                        // Step 2: Count Components
                        // Find root of node i
                        temp_u <= i;
                        if (parent[temp_u] != temp_u && parent[temp_u] < n_reg) begin
                             temp_u <= parent[temp_u];
                        end else begin
                             // Check if it is a root (and valid node)
                             if (temp_u == i && i < n_reg) begin
                                 components <= components + 4'd1;
                             end
                             i <= i + 4'd1;
                        end
                    end else if (i == n_reg && j < n_reg) begin
                        // Step 3: Count Degree Violations
                        if (current_degree[j] > deg_in[j]) begin
                            violations <= violations + (current_degree[j] - deg_in[j]);
                        end
                        j <= j + 4'd1;
                    end else if (j == n_reg) begin
                        // Step 4: Calculate Result
                        // Edges needed to connect C components: (C - 1)
                        // Total edits = (C - 1) + violations
                        if (components > 4'd0) begin
                            total_edits <= (components - 4'd1) + violations;
                        end else begin
                            total_edits <= violations;
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (total_edits <= k_reg) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    // Reset computation registers for next run
                    components <= 4'd0;
                    violations <= 4'd0;
                    loop_count <= 5'd0;
                    i <= 5'd0;
                    j <= 5'd0;
                end
            endcase
        end
    end
    
    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? LOAD : IDLE;
            
            LOAD: begin
                // Transition to COMPUTE if edge_valid_in goes low or after max cycles
                // Simplification: Assume external control stops input, then we proceed to compute
                // We'll add a safety timeout of 64 cycles
                if (edge_valid_in == 1'b0 && edge_processed == 1'b0) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = LOAD;
                end
            end
            
            COMPUTE: begin
                // Check if computation is finished
                if (j == n_reg && edge_count == loop_count) begin
                    next_state = DONE;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            DONE: begin
                next_state = IDLE; // Return to IDLE after one cycle
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule