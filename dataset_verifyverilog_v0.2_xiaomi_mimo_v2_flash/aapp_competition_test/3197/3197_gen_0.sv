module trip_planner (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    input wire [2:0] k,
    input wire [7:0][2:0] x,
    output reg [3:0] result,
    output reg done
);

    // State definition
    localparam IDLE = 3'b000;
    localparam DETECT_CYCLES = 3'b001;
    localparam CALCULATE = 3'b010;
    localparam DONE = 3'b011;
    localparam RESOLVE_CYCLE = 3'b100;

    reg [2:0] state;
    
    // Internal registers
    reg [2:0] current_node;
    reg [7:0] visited;
    reg [7:0] in_path;
    reg [2:0] stack [7:0];
    reg [3:0] stack_ptr;
    
    reg [3:0] cycle_count;
    reg [3:0] cycle_sizes [7:0];
    
    // Registers for calculation (DP)
    reg [3:0] dp [0:8]; // dp[weight] = max participants
    reg [3:0] calc_cycle_idx;
    reg [3:0] calc_weight_idx;
    
    // Helper for cycle resolution
    reg [2:0] cycle_target_node;
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            current_node <= 0;
            visited <= 0;
            in_path <= 0;
            stack_ptr <= 0;
            cycle_count <= 0;
            // Initialize DP to 0
            for (i = 0; i <= 8; i = i + 1) dp[i] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= DETECT_CYCLES;
                        current_node <= 0;
                        visited <= 0;
                        in_path <= 0;
                        stack_ptr <= 0;
                        cycle_count <= 0;
                        // Initialize DP here to be safe
                        for (i = 0; i <= 8; i = i + 1) dp[i] <= 0;
                    end
                end
                
                DETECT_CYCLES: begin
                    if (stack_ptr == 0) begin
                        if (current_node < n) begin
                            if (!visited[current_node]) begin
                                // Start path
                                visited[current_node] <= 1;
                                in_path[current_node] <= 1;
                                stack[0] <= current_node;
                                stack_ptr <= 1;
                            end else begin
                                current_node <= current_node + 1;
                            end
                        end else begin
                            state <= CALCULATE;
                            calc_cycle_idx <= 0;
                            calc_weight_idx <= k;
                        end
                    end else begin
                        // Traverse
                        reg [2:0] head;
                        reg [2:0] next_node;
                        head = stack[stack_ptr - 1];
                        next_node = x[head];
                        
                        if (in_path[next_node]) begin
                            // Cycle detected
                            cycle_target_node <= next_node;
                            state <= RESOLVE_CYCLE;
                            // We need to reset calc_cycle_idx for scanning
                            calc_cycle_idx <= 0;
                        end else if (visited[next_node]) begin
                            // Dead end
                            in_path[head] <= 0;
                            stack_ptr <= stack_ptr - 1;
                        end else begin
                            // Continue
                            visited[next_node] <= 1;
                            in_path[next_node] <= 1;
                            stack[stack_ptr] <= next_node;
                            stack_ptr <= stack_ptr + 1;
                        end
                    end
                end
                
                RESOLVE_CYCLE: begin
                    // Scan stack to find cycle_target_node
                    if (calc_cycle_idx < stack_ptr) begin
                        if (stack[calc_cycle_idx] == cycle_target_node) begin
                            // Found it
                            cycle_sizes[cycle_count] <= stack_ptr - calc_cycle_idx;
                            cycle_count <= cycle_count + 1;
                            
                            // Reset stack and path
                            stack_ptr <= 0;
                            in_path <= 0;
                            
                            // Next node to check
                            current_node <= current_node + 1;
                            
                            state <= DETECT_CYCLES;
                        end else begin
                            calc_cycle_idx <= calc_cycle_idx + 1;
                        end
                    end else begin
                        // Error case (should not happen), return to DETECT
                        state <= DETECT_CYCLES;
                        stack_ptr <= 0;
                        in_path <= 0;
                        current_node <= current_node + 1;
                    end
                end
                
                CALCULATE: begin
                    // DP Loop: Process cycles one by one
                    // Inner loop: update dp[k]...dp[size]
                    if (calc_cycle_idx < cycle_count) begin
                        reg [3:0] size;
                        size = cycle_sizes[calc_cycle_idx];
                        
                        if (calc_weight_idx >= size) begin
                            // Update dp[w]
                            if (dp[calc_weight_idx] < dp[calc_weight_idx - size] + size) begin
                                dp[calc_weight_idx] <= dp[calc_weight_idx - size] + size;
                            end
                            calc_weight_idx <= calc_weight_idx - 1;
                        end else begin
                            // Next cycle
                            calc_cycle_idx <= calc_cycle_idx + 1;
                            calc_weight_idx <= k;
                        end
                    end else begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1;
                    result <= dp[k];
                    if (!start) state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule