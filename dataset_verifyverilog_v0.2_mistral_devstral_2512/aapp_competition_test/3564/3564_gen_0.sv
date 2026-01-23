module island_network_min_tunnel (
    input clk,
    input rst_n,
    input start,
    input [7:0] num_islands,
    input [7:0] num_trees,
    input [31:0] k_ratio,
    input [31:0] island_x [0:7],
    input [31:0] island_y [0:7],
    input [31:0] island_r [0:7],
    input [31:0] tree_x [0:7],
    input [31:0] tree_y [0:7],
    input [31:0] tree_h [0:7],
    output reg [31:0] min_tunnel_length,
    output reg done,
    output reg impossible
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        PREPARE,
        COMPUTE_RANGES,
        BUILD_GRAPH,
        FIND_COMPONENTS,
        CHECK_CONNECTION,
        CALCULATE_MIN,
        DONE
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg [31:0] tree_range [0:7];
    reg [7:0] tree_island [0:7];
    reg [7:0] component [0:7];
    reg [7:0] component_count;
    reg [31:0] min_dist;
    reg [7:0] i, j, t;
    reg [31:0] dx, dy, dist_sq, dist;
    reg [31:0] temp_range;
    reg [7:0] comp_a, comp_b;
    reg [31:0] tunnel_length;

    // Fixed-point constants
    localparam [31:0] ONE = 32'h00010000; // 1.0 in Q16.16
    localparam [31:0] ZERO = 32'h00000000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            impossible <= 0;
            min_tunnel_length <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = PREPARE;
            end
            PREPARE: next_state = COMPUTE_RANGES;
            COMPUTE_RANGES: begin
                if (t == num_trees - 1) next_state = BUILD_GRAPH;
            end
            BUILD_GRAPH: begin
                if (i == num_islands - 1 && j == num_islands - 1) next_state = FIND_COMPONENTS;
            end
            FIND_COMPONENTS: begin
                if (i == num_islands - 1) next_state = CHECK_CONNECTION;
            end
            CHECK_CONNECTION: next_state = CALCULATE_MIN;
            CALCULATE_MIN: begin
                if (i == num_islands - 1 && j == num_islands - 1) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all internal registers
            for (int k = 0; k < 8; k++) begin
                tree_range[k] <= 0;
                tree_island[k] <= 0;
                component[k] <= 0;
            end
            component_count <= 0;
            min_dist <= 0;
            i <= 0;
            j <= 0;
            t <= 0;
            done <= 0;
            impossible <= 0;
            min_tunnel_length <= 0;
        end else begin
            case (state)
                PREPARE: begin
                    // Initialize variables
                    for (int k = 0; k < 8; k++) begin
                        tree_range[k] <= 0;
                        tree_island[k] <= 0;
                        component[k] <= k;
                    end
                    component_count <= num_islands;
                    min_dist <= 32'hFFFFFFFF;
                    i <= 0;
                    j <= 0;
                    t <= 0;
                    done <= 0;
                    impossible <= 0;
                    min_tunnel_length <= 0;
                end
                COMPUTE_RANGES: begin
                    // Calculate range for current tree
                    temp_range = $signed(k_ratio) * $signed(tree_h[t]);
                    tree_range[t] <= temp_range[31:0];
                    
                    // Determine which island the tree is on
                    for (int k = 0; k < num_islands; k++) begin
                        dx = tree_x[t] - island_x[k];
                        dy = tree_y[t] - island_y[k];
                        dist_sq = dx * dx + dy * dy;
                        if (dist_sq < island_r[k] * island_r[k]) begin
                            tree_island[t] <= k;
                        end
                    end
                    
                    // Move to next tree
                    if (t < num_trees - 1) t <= t + 1;
                end
                BUILD_GRAPH: begin
                    // Check if islands i and j are connected
                    if (i != j) begin
                        for (int k = 0; k < num_trees; k++) begin
                            if (tree_island[k] == i) begin
                                dx = tree_x[k] - island_x[j];
                                dy = tree_y[k] - island_y[j];
                                dist_sq = dx * dx + dy * dy;
                                if (dist_sq <= (tree_range[k] + island_r[j]) * (tree_range[k] + island_r[j])) begin
                                    // Union components
                                    if (component[i] != component[j]) begin
                                        // Simple union (no path compression for small N)
                                        for (int m = 0; m < num_islands; m++) begin
                                            if (component[m] == component[j]) begin
                                                component[m] <= component[i];
                                            end
                                        end
                                        component_count <= component_count - 1;
                                    end
                                end
                            end
                        end
                    end
                    
                    // Move to next pair
                    if (j < num_islands - 1) begin
                        j <= j + 1;
                    end else begin
                        j <= 0;
                        if (i < num_islands - 1) begin
                            i <= i + 1;
                        end
                    end
                end
                FIND_COMPONENTS: begin
                    // This state is handled in BUILD_GRAPH
                    // Just increment counters to move to next state
                    if (i < num_islands - 1) begin
                        i <= i + 1;
                    end
                end
                CHECK_CONNECTION: begin
                    // Check number of components
                    if (component_count == 1) begin
                        min_tunnel_length <= 0;
                        done <= 1;
                        impossible <= 0;
                    end else if (component_count > 2) begin
                        impossible <= 1;
                        done <= 1;
                    end else begin
                        // Find the two components
                        comp_a = component[0];
                        comp_b = 8'hFF;
                        for (int k = 1; k < num_islands; k++) begin
                            if (component[k] != comp_a) begin
                                comp_b = component[k];
                                break;
                            end
                        end
                        
                        // Initialize for CALCULATE_MIN
                        i <= 0;
                        j <= 0;
                        min_dist <= 32'hFFFFFFFF;
                    end
                end
                CALCULATE_MIN: begin
                    // Calculate distance between islands in different components
                    if (component[i] != component[j]) begin
                        dx = island_x[i] - island_x[j];
                        dy = island_y[i] - island_y[j];
                        dist_sq = dx * dx + dy * dy;
                        
                        // Calculate actual distance (sqrt)
                        // Simple approximation for small numbers
                        dist = 0;
                        for (int k = 15; k >= 0; k--) begin
                            if ((dist + (1 << k)) * (dist + (1 << k)) <= dist_sq) begin
                                dist = dist + (1 << k);
                            end
                        end
                        
                        // Tunnel length = max(0, distance - r_i - r_j)
                        tunnel_length = dist - island_r[i] - island_r[j];
                        if ($signed(tunnel_length) < 0) begin
                            tunnel_length = 0;
                        end
                        
                        // Update minimum
                        if ($signed(tunnel_length) < $signed(min_dist)) begin
                            min_dist = tunnel_length;
                        end
                    end
                    
                    // Move to next pair
                    if (j < num_islands - 1) begin
                        j <= j + 1;
                    end else begin
                        j <= 0;
                        if (i < num_islands - 1) begin
                            i <= i + 1;
                        end
                    end
                    
                    // If done, output result
                    if (i == num_islands - 1 && j == num_islands - 1) begin
                        min_tunnel_length <= min_dist;
                        done <= 1;
                        impossible <= 0;
                    end
                end
                DONE: begin
                    // Stay in DONE until reset
                end
            endcase
        end
    end

endmodule