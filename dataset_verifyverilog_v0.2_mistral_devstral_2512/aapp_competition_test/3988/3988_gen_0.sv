module graph_planner (
    input clk,
    input rst_n,
    input start_max,
    input start_min,
    input [2:0] s,
    input [2:0] num_vertices,
    input [3:0] num_undirected,
    input [15:0] edge_valid,
    input [2:0] edge_from [15:0],
    input [2:0] edge_to [15:0],
    input edge_type [15:0],
    output reg [3:0] reachable_count,
    output reg [7:0] undirected_orientation,
    output reg busy,
    output reg valid
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        MAX_COMPUTE,
        MIN_COMPUTE,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [7:0] reachable_set;
    reg [7:0] next_reachable_set;
    reg [7:0] visited;
    reg [7:0] next_visited;
    reg [7:0] orientation_mask;
    reg [7:0] next_orientation_mask;
    reg [2:0] current_vertex;
    reg [2:0] next_current_vertex;
    reg [3:0] cycle_count;
    reg [3:0] next_cycle_count;
    reg [2:0] vertex_counter;
    reg [2:0] next_vertex_counter;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            reachable_set <= 0;
            visited <= 0;
            orientation_mask <= 0;
            current_vertex <= 0;
            cycle_count <= 0;
            vertex_counter <= 0;
            busy <= 0;
            valid <= 0;
        end else begin
            current_state <= next_state;
            reachable_set <= next_reachable_set;
            visited <= next_visited;
            orientation_mask <= next_orientation_mask;
            current_vertex <= next_current_vertex;
            cycle_count <= next_cycle_count;
            vertex_counter <= next_vertex_counter;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        next_reachable_set = reachable_set;
        next_visited = visited;
        next_orientation_mask = orientation_mask;
        next_current_vertex = current_vertex;
        next_cycle_count = cycle_count;
        next_vertex_counter = vertex_counter;
        busy = 0;
        valid = 0;

        case (current_state)
            IDLE: begin
                if (start_max) begin
                    next_state = MAX_COMPUTE;
                    next_reachable_set = 1 << s;
                    next_visited = 1 << s;
                    next_orientation_mask = 0;
                    next_current_vertex = s;
                    next_cycle_count = 0;
                    next_vertex_counter = 0;
                    busy = 1;
                end else if (start_min) begin
                    next_state = MIN_COMPUTE;
                    next_reachable_set = 1 << s;
                    next_visited = 1 << s;
                    next_orientation_mask = 0;
                    next_current_vertex = s;
                    next_cycle_count = 0;
                    next_vertex_counter = 0;
                    busy = 1;
                end
            end

            MAX_COMPUTE: begin
                busy = 1;
                if (cycle_count < 8) begin
                    // Process current vertex
                    for (int i = 0; i < 16; i++) begin
                        if (edge_valid[i] && (edge_from[i] == current_vertex || edge_to[i] == current_vertex)) begin
                            if (edge_type[i]) begin // Undirected edge
                                if (edge_from[i] == current_vertex) begin
                                    if (!(visited & (1 << edge_to[i]))) begin
                                        next_reachable_set = reachable_set | (1 << edge_to[i]);
                                        next_visited = visited | (1 << edge_to[i]);
                                        next_orientation_mask = orientation_mask | (1 << i);
                                    end
                                end else if (edge_to[i] == current_vertex) begin
                                    if (!(visited & (1 << edge_from[i]))) begin
                                        next_reachable_set = reachable_set | (1 << edge_from[i]);
                                        next_visited = visited | (1 << edge_from[i]);
                                        // Orientation bit remains 0 for this case
                                    end
                                end
                            end else begin // Directed edge
                                if (edge_from[i] == current_vertex && !(visited & (1 << edge_to[i]))) begin
                                    next_reachable_set = reachable_set | (1 << edge_to[i]);
                                    next_visited = visited | (1 << edge_to[i]);
                                end
                            end
                        end
                    end

                    // Move to next vertex
                    if (vertex_counter < 7) begin
                        next_vertex_counter = vertex_counter + 1;
                    end else begin
                        next_vertex_counter = 0;
                        next_cycle_count = cycle_count + 1;
                    end

                    // Find next unvisited vertex
                    for (int v = 0; v < 8; v++) begin
                        if ((reachable_set & (1 << v)) && !(visited & (1 << v))) begin
                            next_current_vertex = v;
                            break;
                        end
                    end

                    // Check if done
                    if (next_cycle_count == 8 || (reachable_set == visited)) begin
                        next_state = DONE;
                    end
                end else begin
                    next_state = DONE;
                end
            end

            MIN_COMPUTE: begin
                busy = 1;
                if (cycle_count < 8) begin
                    // Process current vertex
                    for (int i = 0; i < 16; i++) begin
                        if (edge_valid[i] && edge_from[i] == current_vertex) begin
                            if (edge_type[i]) begin // Undirected edge treated as directed
                                if (!(visited & (1 << edge_to[i]))) begin
                                    next_reachable_set = reachable_set | (1 << edge_to[i]);
                                    next_visited = visited | (1 << edge_to[i]);
                                    next_orientation_mask = orientation_mask | (1 << i);
                                end
                            end else begin // Directed edge
                                if (!(visited & (1 << edge_to[i]))) begin
                                    next_reachable_set = reachable_set | (1 << edge_to[i]);
                                    next_visited = visited | (1 << edge_to[i]);
                                end
                            end
                        end
                    end

                    // Move to next vertex
                    if (vertex_counter < 7) begin
                        next_vertex_counter = vertex_counter + 1;
                    end else begin
                        next_vertex_counter = 0;
                        next_cycle_count = cycle_count + 1;
                    end

                    // Find next unvisited vertex
                    for (int v = 0; v < 8; v++) begin
                        if ((reachable_set & (1 << v)) && !(visited & (1 << v))) begin
                            next_current_vertex = v;
                            break;
                        end
                    end

                    // Check if done
                    if (next_cycle_count == 8 || (reachable_set == visited)) begin
                        next_state = DONE;
                    end
                end else begin
                    next_state = DONE;
                end
            end

            DONE: begin
                // Count reachable vertices
                reachable_count = 0;
                for (int i = 0; i < 8; i++) begin
                    if (reachable_set[i])
                        reachable_count = reachable_count + 1;
                end

                undirected_orientation = orientation_mask;
                busy = 0;
                valid = 1;
                next_state = IDLE;
            end
        endcase
    end

endmodule