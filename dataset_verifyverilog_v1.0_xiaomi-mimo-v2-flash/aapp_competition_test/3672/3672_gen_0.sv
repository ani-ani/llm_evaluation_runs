module coexistence_check (
    input clk, rst_n, start,
    input [3:0] edge_count,
    input [4:0] edge_i_j[0:15],
    output reg result, done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] DONE = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] edge_idx;           // Current edge being processed
    reg [3:0] island_i, island_j; // Islands from current edge
    reg [15:0] visited;           // One-hot visited array
    reg [15:0] color;             // Color array (0=Zax, 1=Xaz)
    reg conflict_found;           // Flag for coloring conflict
    reg [3:0] cycle_count;        // Prevent infinite loops
    localparam [3:0] MAX_CYCLES = 4'd15; // Sufficient for 16 edges

    // DFS stack implementation (4-bit stack, max 16 entries)
    reg [3:0] stack[0:15];
    reg [3:0] stack_ptr;
    reg stack_full;
    reg stack_empty;

    integer i;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            edge_idx <= 4'd0;
            island_i <= 4'd0;
            island_j <= 4'd0;
            visited <= 16'd0;
            color <= 16'd0;
            conflict_found <= 1'b0;
            cycle_count <= 4'd0;
            stack_ptr <= 4'd0;
            stack_full <= 1'b0;
            stack_empty <= 1'b1;
            // Initialize stack
            for (i = 0; i < 16; i = i + 1) begin
                stack[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    edge_idx <= 4'd0;
                    visited <= 16'd0;
                    color <= 16'd0;
                    conflict_found <= 1'b0;
                    cycle_count <= 4'd0;
                    stack_ptr <= 4'd0;
                    stack_full <= 1'b0;
                    stack_empty <= 1'b1;
                    for (i = 0; i < 16; i = i + 1) begin
                        stack[i] <= 4'd0;
                    end
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    if (edge_idx < edge_count && !conflict_found) begin
                        // Extract island indices from edge_i_j
                        island_i <= edge_i_j[edge_idx][4:2];
                        island_j <= edge_i_j[edge_idx][1:0];
                        state <= CHECK;
                        cycle_count <= 4'd0;
                    end else begin
                        // All edges processed or conflict found
                        state <= DONE;
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Perform BFS/DFS coloring check
                    // Start with island_i if not visited
                    if (!visited[island_i]) begin
                        visited[island_i] <= 1'b1;
                        color[island_i] <= 1'b0; // Assign color 0
                        stack[0] <= island_i;
                        stack_ptr <= 4'd1;
                        stack_empty <= 1'b0;
                    end

                    // Process stack
                    if (stack_empty == 1'b0) begin
                        // Pop from stack
                        reg [3:0] current_island;
                        reg [3:0] temp_ptr;
                        temp_ptr = stack_ptr - 4'd1;
                        current_island = stack[temp_ptr];
                        stack_ptr <= temp_ptr;
                        if (temp_ptr == 4'd0) begin
                            stack_empty <= 1'b1;
                        end

                        // Check all edges for neighbors
                        for (int k = 0; k < 16; k = k + 1) begin
                            if (k < edge_count) begin
                                // Check if current_island is part of edge k
                                if (edge_i_j[k][4:2] == current_island) begin
                                    // Neighbor is island_j of this edge
                                    reg [3:0] neighbor;
                                    neighbor = edge_i_j[k][1:0];
                                    if (!visited[neighbor]) begin
                                        visited[neighbor] <= 1'b1;
                                        color[neighbor] <= ~color[current_island];
                                        if (stack_ptr < 4'd15) begin
                                            stack[stack_ptr] <= neighbor;
                                            stack_ptr <= stack_ptr + 4'd1;
                                            stack_empty <= 1'b0;
                                        end else begin
                                            stack_full <= 1'b1;
                                        end
                                    end else begin
                                        // Check for conflict
                                        if (color[neighbor] == color[current_island]) begin
                                            conflict_found <= 1'b1;
                                        end
                                    end
                                end
                                if (edge_i_j[k][1:0] == current_island) begin
                                    // Neighbor is island_i of this edge
                                    reg [3:0] neighbor;
                                    neighbor = edge_i_j[k][4:2];
                                    if (!visited[neighbor]) begin
                                        visited[neighbor] <= 1'b1;
                                        color[neighbor] <= ~color[current_island];
                                        if (stack_ptr < 4'd15) begin
                                            stack[stack_ptr] <= neighbor;
                                            stack_ptr <= stack_ptr + 4'd1;
                                            stack_empty <= 1'b0;
                                        end else begin
                                            stack_full <= 1'b1;
                                        end
                                    end else begin
                                        // Check for conflict
                                        if (color[neighbor] == color[current_island]) begin
                                            conflict_found <= 1'b1;
                                        end
                                    end
                                end
                            end
                        end
                    end else begin
                        // No more nodes in stack for this component
                        state <= LOAD;
                        edge_idx <= edge_idx + 4'd1;
                    end

                    // Exit if conflict found or max cycles exceeded
                    if (conflict_found || cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    result <= ~conflict_found;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule