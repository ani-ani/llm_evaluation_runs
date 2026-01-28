module prime_minister_happy (
    input clk,
    input rst_n,
    input start,
    input [3:0] num_cities,
    input [4:0] K,
    input [7:0] x0, x1, x2, x3,
    input [7:0] y0, y1, y2, y3,
    input [7:0] pop0, pop1, pop2, pop3,
    output reg [23:0] sq_dist_result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE_DISTANCES = 4'd1;
    localparam [3:0] SORT_DISTANCES = 4'd2;
    localparam [3:0] INIT_GRAPH = 4'd3;
    localparam [3:0] ADD_EDGES = 4'd4;
    localparam [3:0] FIND_COMPONENTS = 4'd5;
    localparam [3:0] CHECK_SUBSET = 4'd6;
    localparam [3:0] UPDATE_RESULT = 4'd7;
    localparam [3:0] DONE_STATE = 4'd8;

    reg [3:0] state, next_state;

    // Internal registers
    reg [23:0] distances [0:5];
    reg [23:0] sorted_distances [0:5];
    reg [23:0] current_distance;
    reg [3:0] distance_index;
    reg [3:0] sort_i, sort_j;
    reg [23:0] temp_distance;

    // Graph and component registers
    reg [3:0] graph [0:3];
    reg [3:0] component [0:3];
    reg [3:0] component_id;
    reg [3:0] node_i, node_j;
    reg [3:0] component_count;

    // Subset sum DP registers
    reg [29:0] dp [0:29];
    reg [3:0] pop_index;
    reg [3:0] mod_index;
    reg [7:0] current_pop;
    reg [29:0] dp_next [0:29];
    reg found_valid_subset;

    // Control registers
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Coordinates and populations
    reg [7:0] x [0:3];
    reg [7:0] y [0:3];
    reg [7:0] pop [0:3];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            sq_dist_result <= 24'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize distances
            for (distance_index = 0; distance_index < 6; distance_index = distance_index + 1) begin
                distances[distance_index] <= 24'd0;
                sorted_distances[distance_index] <= 24'd0;
            end

            // Initialize graph
            for (node_i = 0; node_i < 4; node_i = node_i + 1) begin
                graph[node_i] <= 4'd0;
                component[node_i] <= 4'd0;
            end

            // Initialize DP
            for (mod_index = 0; mod_index < 30; mod_index = mod_index + 1) begin
                dp[mod_index] <= 30'd0;
                dp_next[mod_index] <= 30'd0;
            end

            // Initialize other registers
            current_distance <= 24'd0;
            distance_index <= 4'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            temp_distance <= 24'd0;
            component_id <= 4'd0;
            component_count <= 4'd0;
            pop_index <= 4'd0;
            current_pop <= 8'd0;
            found_valid_subset <= 1'b0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Load inputs
                        x[0] <= x0;
                        x[1] <= x1;
                        x[2] <= x2;
                        x[3] <= x3;
                        y[0] <= y0;
                        y[1] <= y1;
                        y[2] <= y2;
                        y[3] <= y3;
                        pop[0] <= pop0;
                        pop[1] <= pop1;
                        pop[2] <= pop2;
                        pop[3] <= pop3;
                        next_state <= COMPUTE_DISTANCES;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE_DISTANCES: begin
                    // Compute all pairwise squared distances
                    distance_index <= 4'd0;
                    for (node_i = 0; node_i < 4; node_i = node_i + 1) begin
                        for (node_j = node_i + 1; node_j < 4; node_j = node_j + 1) begin
                            if (node_i != node_j) begin
                                temp_distance <= (x[node_i] - x[node_j]) * (x[node_i] - x[node_j]) + 
                                               (y[node_i] - y[node_j]) * (y[node_i] - y[node_j]);
                                distances[distance_index] <= temp_distance;
                                distance_index <= distance_index + 1;
                            end
                        end
                    end
                    next_state <= SORT_DISTANCES;
                end

                SORT_DISTANCES: begin
                    // Simple bubble sort for distances
                    for (sort_i = 0; sort_i < 5; sort_i = sort_i + 1) begin
                        for (sort_j = 0; sort_j < 5 - sort_i; sort_j = sort_j + 1) begin
                            if (distances[sort_j] > distances[sort_j + 1]) begin
                                temp_distance <= distances[sort_j];
                                distances[sort_j] <= distances[sort_j + 1];
                                distances[sort_j + 1] <= temp_distance;
                            end
                        end
                    end
                    // Copy to sorted_distances
                    for (distance_index = 0; distance_index < 6; distance_index = distance_index + 1) begin
                        sorted_distances[distance_index] <= distances[distance_index];
                    end
                    next_state <= INIT_GRAPH;
                end

                INIT_GRAPH: begin
                    // Initialize graph with no edges
                    for (node_i = 0; node_i < 4; node_i = node_i + 1) begin
                        graph[node_i] <= 4'd0;
                    end
                    distance_index <= 4'd0;
                    next_state <= ADD_EDGES;
                end

                ADD_EDGES: begin
                    // Add edges with current distance
                    current_distance <= sorted_distances[distance_index];
                    for (node_i = 0; node_i < 4; node_i = node_i + 1) begin
                        for (node_j = node_i + 1; node_j < 4; node_j = node_j + 1) begin
                            if ((x[node_i] - x[node_j]) * (x[node_i] - x[node_j]) + 
                                (y[node_i] - y[node_j]) * (y[node_i] - y[node_j]) == current_distance) begin
                                graph[node_i] <= graph[node_i] | (1 << node_j);
                                graph[node_j] <= graph[node_j] | (1 << node_i);
                            end
                        end
                    end
                    next_state <= FIND_COMPONENTS;
                end

                FIND_COMPONENTS: begin
                    // Find connected components using BFS
                    component_count <= 4'd0;
                    for (node_i = 0; node_i < 4; node_i = node_i + 1) begin
                        component[node_i] <= 4'd0;
                    end
                    
                    for (node_i = 0; node_i < 4; node_i = node_i + 1) begin
                        if (component[node_i] == 4'd0) begin
                            component_count <= component_count + 4'd1;
                            component_id <= component_count;
                            // BFS starting from node_i
                            component[node_i] <= component_id;
                            for (node_j = 0; node_j < 4; node_j = node_j + 1) begin
                                if ((graph[node_i] >> node_j) & 1 && component[node_j] == 4'd0) begin
                                    component[node_j] <= component_id;
                                end
                            end
                        end
                    end
                    next_state <= CHECK_SUBSET;
                end

                CHECK_SUBSET: begin
                    // Check each component for valid subset sum
                    found_valid_subset <= 1'b0;
                    for (component_id = 1; component_id <= component_count; component_id = component_id + 1) begin
                        // Initialize DP for this component
                        for (mod_index = 0; mod_index < 30; mod_index = mod_index + 1) begin
                            dp[mod_index] <= 30'd0;
                        end
                        dp[0] <= 30'd1; // Empty subset
                        
                        // Collect populations in this component
                        for (node_i = 0; node_i < 4; node_i = node_i + 1) begin
                            if (component[node_i] == component_id) begin
                                current_pop <= pop[node_i];
                                for (mod_index = 0; mod_index < 30; mod_index = mod_index + 1) begin
                                    if (dp[mod_index]) begin
                                        dp_next[(mod_index + current_pop) % K] <= 1'b1;
                                    end
                                end
                                for (mod_index = 0; mod_index < 30; mod_index = mod_index + 1) begin
                                    dp[mod_index] <= dp[mod_index] | dp_next[mod_index];
                                    dp_next[mod_index] <= 30'd0;
                                end
                            end
                        end
                        
                        // Check if any non-empty subset sums to 0 mod K
                        if (dp[0] && (component_id > 1)) begin
                            found_valid_subset <= 1'b1;
                        end
                    end
                    
                    if (found_valid_subset) begin
                        next_state <= UPDATE_RESULT;
                    end else begin
                        distance_index <= distance_index + 1;
                        if (distance_index < 6) begin
                            next_state <= ADD_EDGES;
                        end else begin
                            next_state <= DONE_STATE;
                        end
                    end
                end

                UPDATE_RESULT: begin
                    sq_dist_result <= current_distance;
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule