module cave_nav(
    input clk,
    input rst_n,
    input start,
    input [15:0] A,
    input [15:0] H,
    input [4:0] n,
    input [4:0] m,
    input [127:0] edges [0:31],
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SEARCH = 3'd1;
    localparam [2:0] UPDATE_BEST = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Stack and path tracking
    reg [4:0] stack [0:15];
    reg [4:0] current_path [0:15];
    reg [15:0] current_health;
    reg [15:0] best_health;
    reg [4:0] stack_ptr;
    reg [4:0] path_length;
    reg [4:0] current_node;
    reg [4:0] next_node;
    reg [4:0] edge_index;
    reg [4:0] visited [0:15];
    reg [4:0] visited_count;

    // State machine
    reg [2:0] state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // Combat simulation
    wire [15:0] enemy_a;
    wire [15:0] enemy_h;
    wire [15:0] hits_to_kill;
    wire [15:0] damage;

    assign enemy_a = edges[edge_index][31:16];
    assign enemy_h = edges[edge_index][15:0];

    // Calculate hits_to_kill and damage
    always @(*) begin
        if (enemy_h == 0) begin
            hits_to_kill = 16'd0;
            damage = 16'd0;
        end else begin
            hits_to_kill = (enemy_h + A - 1) / A;
            damage = (hits_to_kill - 1) * enemy_a;
        end
    end

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            stack_ptr <= 5'd0;
            path_length <= 5'd0;
            current_node <= 5'd1;
            current_health <= H;
            best_health <= 16'd0;
            edge_index <= 5'd0;
            visited_count <= 5'd0;
            for (integer i = 0; i < 16; i = i + 1) begin
                stack[i] <= 5'd0;
                current_path[i] <= 5'd0;
                visited[i] <= 5'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        state <= SEARCH;
                        current_node <= 5'd1;
                        current_health <= H;
                        best_health <= 16'd0;
                        stack_ptr <= 5'd0;
                        path_length <= 5'd0;
                        edge_index <= 5'd0;
                        visited_count <= 5'd0;
                        for (integer i = 0; i < 16; i = i + 1) begin
                            visited[i] <= 5'd0;
                        end
                    end
                end

                SEARCH: begin
                    cycle_count <= cycle_count + 16'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end else begin
                        if (current_node == n) begin
                            state <= UPDATE_BEST;
                        end else begin
                            if (edge_index < m) begin
                                // Check if edge is valid and not visited
                                if (edges[edge_index][47:40] == current_node) begin
                                    next_node = edges[edge_index][39:32];
                                    if (next_node != 5'd0 && !visited[next_node]) begin
                                        // Check if health is sufficient
                                        if (current_health > damage) begin
                                            // Push to stack
                                            stack[stack_ptr] = edge_index;
                                            stack_ptr = stack_ptr + 5'd1;
                                            current_path[path_length] = next_node;
                                            path_length = path_length + 5'd1;
                                            visited[next_node] = 5'd1;
                                            visited_count = visited_count + 5'd1;
                                            current_health = current_health - damage;
                                            current_node = next_node;
                                            edge_index = 5'd0;
                                        end else begin
                                            edge_index = edge_index + 5'd1;
                                        end
                                    end else begin
                                        edge_index = edge_index + 5'd1;
                                    end
                                end else begin
                                    edge_index = edge_index + 5'd1;
                                end
                            end else begin
                                // Backtrack
                                if (stack_ptr > 5'd0) begin
                                    stack_ptr = stack_ptr - 5'd1;
                                    edge_index = stack[stack_ptr] + 5'd1;
                                    path_length = path_length - 5'd1;
                                    current_node = current_path[path_length];
                                    visited[current_path[path_length]] = 5'd0;
                                    visited_count = visited_count - 5'd1;
                                    // Restore health
                                    current_health = current_health + damage;
                                end else begin
                                    state <= DONE_STATE;
                                end
                            end
                        end
                    end
                end

                UPDATE_BEST: begin
                    if (current_health > best_health) begin
                        best_health = current_health;
                    end
                    // Backtrack
                    if (stack_ptr > 5'd0) begin
                        stack_ptr = stack_ptr - 5'd1;
                        edge_index = stack[stack_ptr] + 5'd1;
                        path_length = path_length - 5'd1;
                        current_node = current_path[path_length];
                        visited[current_path[path_length]] = 5'd0;
                        visited_count = visited_count - 5'd1;
                        current_health = current_health + damage;
                        state <= SEARCH;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    result <= best_health;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule