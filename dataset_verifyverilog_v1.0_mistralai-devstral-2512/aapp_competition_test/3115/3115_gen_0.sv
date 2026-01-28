module tournament_checker(
    input clk,
    input rst_n,
    input start,
    input [3:0] player_a,
    input [3:0] player_b,
    input [1:0] match_type,
    input match_valid,
    input match_end,
    output reg done,
    output reg consistent
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] ACCEPT_INPUTS = 2'd1;
    localparam [1:0] CHECK_CONSISTENCY = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2048;

    // Equality groups: 16 players, each with a 16-bit bitmask
    reg [15:0] eq_group [0:15];
    integer i, j, k;

    // Strict inequality adjacency matrix: 16x16 directed graph
    reg [15:0] strict_ineq [0:15];

    // Temporary registers for consistency check
    reg [15:0] visited;
    reg [15:0] stack;
    reg [3:0] stack_ptr;
    reg [3:0] current_node;
    reg [3:0] target_node;
    reg cycle_detected;
    reg conflict_detected;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            consistent <= 1'b1;
            cycle_count <= 8'd0;
            
            // Initialize equality groups: each player is only in their own group
            for (i = 0; i < 16; i = i + 1) begin
                eq_group[i] <= 16'd0;
                eq_group[i][i] <= 1'b1;
            end
            
            // Initialize strict inequality matrix: no edges
            for (i = 0; i < 16; i = i + 1) begin
                strict_ineq[i] <= 16'd0;
            end
            
            // Initialize temporary registers
            visited <= 16'd0;
            stack <= 16'd0;
            stack_ptr <= 4'd0;
            current_node <= 4'd0;
            target_node <= 4'd0;
            cycle_detected <= 1'b0;
            conflict_detected <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= ACCEPT_INPUTS;
                    end
                end
                
                ACCEPT_INPUTS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (match_valid) begin
                        // Process the current match
                        if (match_type == 2'd0) begin
                            // Equality constraint: merge groups
                            reg [15:0] merged_mask;
                            merged_mask = eq_group[player_a] | eq_group[player_b];
                            
                            // Update all players in both groups to have the merged mask
                            for (i = 0; i < 16; i = i + 1) begin
                                if (eq_group[player_a][i] || eq_group[player_b][i]) begin
                                    eq_group[i] <= merged_mask;
                                end
                            end
                        end else if (match_type == 2'd1) begin
                            // Strict inequality: add directed edge
                            strict_ineq[player_a][player_b] <= 1'b1;
                        end
                    end
                    
                    // Transition to consistency check when match_end is high
                    if (match_end) begin
                        state <= CHECK_CONSISTENCY;
                        cycle_count <= 8'd0;
                        
                        // Initialize temporary registers for consistency check
                        visited <= 16'd0;
                        stack <= 16'd0;
                        stack_ptr <= 4'd0;
                        current_node <= 4'd0;
                        target_node <= 4'd0;
                        cycle_detected <= 1'b0;
                        conflict_detected <= 1'b0;
                    end
                end
                
                CHECK_CONSISTENCY: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check for direct conflicts: A=B and A>B or B>A
                    if (!conflict_detected) begin
                        for (i = 0; i < 16; i = i + 1) begin
                            for (j = 0; j < 16; j = j + 1) begin
                                if (eq_group[i][j] && (strict_ineq[i][j] || strict_ineq[j][i])) begin
                                    conflict_detected <= 1'b1;
                                end
                            end
                        end
                    end
                    
                    // Check for cycles in the strict inequality graph
                    if (!cycle_detected && !conflict_detected) begin
                        // Simple DFS for cycle detection
                        if (stack_ptr == 4'd0) begin
                            // Start DFS from node 0
                            current_node <= 4'd0;
                            visited[0] <= 1'b1;
                            stack[0] <= 1'b1;
                            stack_ptr <= 4'd1;
                        end else begin
                            // Check neighbors
                            reg found;
                            found = 1'b0;
                            for (j = 0; j < 16; j = j + 1) begin
                                if (strict_ineq[current_node][j] && !visited[j]) begin
                                    visited[j] <= 1'b1;
                                    stack[j] <= 1'b1;
                                    stack_ptr <= stack_ptr + 4'd1;
                                    current_node <= j;
                                    found = 1'b1;
                                end else if (strict_ineq[current_node][j] && stack[j]) begin
                                    // Cycle detected
                                    cycle_detected <= 1'b1;
                                    found = 1'b1;
                                end
                            end
                            
                            if (!found && stack_ptr > 4'd0) begin
                                // Backtrack
                                stack_ptr <= stack_ptr - 4'd1;
                                stack[current_node] <= 1'b0;
                                current_node <= 4'd0;
                                for (j = 0; j < 16; j = j + 1) begin
                                    if (stack[j]) begin
                                        current_node <= j;
                                    end
                                end
                            end
                        end
                    end
                    
                    // Transition to DONE state when checks are complete or max cycles reached
                    if (conflict_detected || cycle_detected || cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                        consistent <= !(conflict_detected || cycle_detected);
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    if (start) begin
                        state <= IDLE;
                    end else begin
                        done <= 1'b0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule