module GraphColoring(
    input clk,
    input rst_n,
    input start,
    input [3:0] edge_count,
    input [2:0] u_0, u_1, u_2, u_3, u_4, u_5, u_6, u_7, u_8, u_9, u_10, u_11, u_12, u_13, u_14, u_15,
    input [2:0] v_0, v_1, v_2, v_3, v_4, v_5, v_6, v_7, v_8, v_9, v_10, v_11, v_12, v_13, v_14, v_15,
    input [1:0] c_0, c_1, c_2, c_3, c_4, c_5, c_6, c_7, c_8, c_9, c_10, c_11, c_12, c_13, c_14, c_15,
    output reg done,
    output reg impossible,
    output reg [3:0] min_lounges
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] CHECK = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Edge storage
    reg [2:0] u [0:15];
    reg [2:0] v [0:15];
    reg [1:0] c [0:15];

    // Node assignments
    reg [7:0] assigned;
    reg [7:0] visited;
    reg [7:0] current_assignment;
    reg [3:0] current_lounges;
    reg [3:0] best_lounges;

    // BFS queue
    reg [2:0] queue [0:7];
    reg [2:0] queue_head;
    reg [2:0] queue_tail;

    // Edge processing
    integer i;
    integer j;
    reg conflict;
    reg valid_assignment;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            impossible <= 1'b0;
            min_lounges <= 4'd0;
            cycle_count <= 8'd0;
            
            // Initialize edge storage
            for (i = 0; i < 16; i = i + 1) begin
                u[i] <= 3'd0;
                v[i] <= 3'd0;
                c[i] <= 2'd0;
            end
            
            // Initialize node assignments
            assigned <= 8'd0;
            visited <= 8'd0;
            current_assignment <= 8'd0;
            current_lounges <= 4'd0;
            best_lounges <= 4'd8;
            
            // Initialize queue
            queue_head <= 3'd0;
            queue_tail <= 3'd0;
            for (i = 0; i < 8; i = i + 1) begin
                queue[i] <= 3'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    min_lounges <= 4'd0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Load edge data
                    u[0] <= u_0; v[0] <= v_0; c[0] <= c_0;
                    u[1] <= u_1; v[1] <= v_1; c[1] <= c_1;
                    u[2] <= u_2; v[2] <= v_2; c[2] <= c_2;
                    u[3] <= u_3; v[3] <= v_3; c[3] <= c_3;
                    u[4] <= u_4; v[4] <= v_4; c[4] <= c_4;
                    u[5] <= u_5; v[5] <= v_5; c[5] <= c_5;
                    u[6] <= u_6; v[6] <= v_6; c[6] <= c_6;
                    u[7] <= u_7; v[7] <= v_7; c[7] <= c_7;
                    u[8] <= u_8; v[8] <= v_8; c[8] <= c_8;
                    u[9] <= u_9; v[9] <= v_9; c[9] <= c_9;
                    u[10] <= u_10; v[10] <= v_10; c[10] <= c_10;
                    u[11] <= u_11; v[11] <= v_11; c[11] <= c_11;
                    u[12] <= u_12; v[12] <= v_12; c[12] <= c_12;
                    u[13] <= u_13; v[13] <= v_13; c[13] <= c_13;
                    u[14] <= u_14; v[14] <= v_14; c[14] <= c_14;
                    u[15] <= u_15; v[15] <= v_15; c[15] <= c_15;
                    
                    // Initialize for processing
                    assigned <= 8'd0;
                    visited <= 8'd0;
                    current_assignment <= 8'd0;
                    current_lounges <= 4'd0;
                    best_lounges <= 4'd8;
                    
                    // Initialize queue
                    queue_head <= 3'd0;
                    queue_tail <= 3'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        queue[i] <= 3'd0;
                    end
                    
                    state <= PROCESS;
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all nodes
                    if (visited == 8'd255 || cycle_count >= MAX_CYCLES) begin
                        state <= CHECK;
                    end else begin
                        // Find first unvisited node
                        for (i = 0; i < 8; i = i + 1) begin
                            if (!visited[i]) begin
                                // Start BFS from this node
                                queue[queue_tail] <= i;
                                queue_tail <= (queue_tail + 3'd1) % 8;
                                visited[i] <= 1'b1;
                                current_assignment[i] <= 1'b0;
                                current_lounges <= current_lounges + 4'd0;
                                break;
                            end
                        end
                        
                        // Process queue
                        if (queue_head != queue_tail) begin
                            reg [2:0] current_node;
                            current_node <= queue[queue_head];
                            queue_head <= (queue_head + 3'd1) % 8;
                            
                            // Try both assignments for current node
                            for (j = 0; j < 2; j = j + 1) begin
                                reg [7:0] temp_assignment;
                                reg [3:0] temp_lounges;
                                reg temp_conflict;
                                
                                temp_assignment <= current_assignment;
                                temp_lounges <= current_lounges;
                                temp_conflict <= 1'b0;
                                
                                // Try assignment j
                                temp_assignment[current_node] <= j;
                                temp_lounges <= temp_lounges + (j ? 4'd1 : 4'd0);
                                
                                // Check all edges involving current_node
                                for (i = 0; i < edge_count; i = i + 1) begin
                                    if ((u[i] == current_node || v[i] == current_node) && 
                                        (visited[u[i]] || visited[v[i]])) begin
                                        reg [2:0] other_node;
                                        other_node <= (u[i] == current_node) ? v[i] : u[i];
                                        
                                        if (c[i] == 2'd0) begin
                                            // Both must be 0
                                            if (temp_assignment[current_node] != 1'b0 || 
                                                (visited[other_node] && temp_assignment[other_node] != 1'b0)) begin
                                                temp_conflict <= 1'b1;
                                            end
                                        end else if (c[i] == 2'd2) begin
                                            // Both must be 1
                                            if (temp_assignment[current_node] != 1'b1 || 
                                                (visited[other_node] && temp_assignment[other_node] != 1'b1)) begin
                                                temp_conflict <= 1'b1;
                                            end
                                        end else if (c[i] == 2'd1) begin
                                            // Must be different
                                            if (visited[other_node]) begin
                                                if (temp_assignment[current_node] == temp_assignment[other_node]) begin
                                                    temp_conflict <= 1'b1;
                                                end
                                            end
                                        end
                                    end
                                end
                                
                                if (!temp_conflict) begin
                                    // Valid assignment, continue BFS
                                    current_assignment <= temp_assignment;
                                    current_lounges <= temp_lounges;
                                    
                                    // Add unvisited neighbors to queue
                                    for (i = 0; i < edge_count; i = i + 1) begin
                                        if (u[i] == current_node && !visited[v[i]]) begin
                                            queue[queue_tail] <= v[i];
                                            queue_tail <= (queue_tail + 3'd1) % 8;
                                            visited[v[i]] <= 1'b1;
                                        end else if (v[i] == current_node && !visited[u[i]]) begin
                                            queue[queue_tail] <= u[i];
                                            queue_tail <= (queue_tail + 3'd1) % 8;
                                            visited[u[i]] <= 1'b1;
                                        end
                                    end
                                    break;
                                end
                            end
                            
                            if (j == 1 && temp_conflict) begin
                                // Both assignments failed, backtrack
                                if (queue_head == queue_tail) begin
                                    // No solution
                                    impossible <= 1'b1;
                                    state <= FINISH;
                                end else begin
                                    // Backtrack to previous node
                                    queue_tail <= (queue_tail - 3'd1 + 8) % 8;
                                    current_node <= queue[queue_tail];
                                    visited[current_node] <= 1'b0;
                                    current_assignment[current_node] <= 1'b0;
                                    current_lounges <= current_lounges - (current_assignment[current_node] ? 4'd1 : 4'd0);
                                end
                            end
                        end
                    end
                end

                CHECK: begin
                    // Verify all constraints
                    conflict <= 1'b0;
                    for (i = 0; i < edge_count; i = i + 1) begin
                        if (c[i] == 2'd0) begin
                            if (current_assignment[u[i]] != 1'b0 || current_assignment[v[i]] != 1'b0) begin
                                conflict <= 1'b1;
                            end
                        end else if (c[i] == 2'd2) begin
                            if (current_assignment[u[i]] != 1'b1 || current_assignment[v[i]] != 1'b1) begin
                                conflict <= 1'b1;
                            end
                        end else if (c[i] == 2'd1) begin
                            if (current_assignment[u[i]] == current_assignment[v[i]]) begin
                                conflict <= 1'b1;
                            end
                        end
                    end
                    
                    if (conflict) begin
                        impossible <= 1'b1;
                    end else begin
                        // Update best solution
                        if (current_lounges < best_lounges) begin
                            best_lounges <= current_lounges;
                        end
                    end
                    
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    if (!impossible) begin
                        min_lounges <= best_lounges;
                    end else begin
                        min_lounges <= 4'd0;
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule