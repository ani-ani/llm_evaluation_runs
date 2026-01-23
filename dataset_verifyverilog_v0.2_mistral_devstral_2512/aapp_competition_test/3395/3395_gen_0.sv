module steel_age_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] graph [7:0][7:0],
    input [7:0] iron_mask,
    input [7:0] coal_mask,
    output reg [3:0] min_settlers,
    output reg done,
    output reg possible
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        EXPLORE,
        CHECK_PATHS,
        COMPLETE
    } state_t;

    state_t current_state, next_state;

    // Frontier queue (max 8 nodes)
    reg [2:0] frontier [0:7];
    reg [2:0] frontier_head, frontier_tail;
    reg [2:0] frontier_count;

    // Distance/cost tracking (0-15)
    reg [3:0] distance [0:7];
    reg [3:0] min_iron_cost, min_coal_cost;

    // Resource flags
    reg [7:0] iron_reached, coal_reached;

    // Current node being processed
    reg [2:0] current_node;

    // Temporary variables
    reg [2:0] next_node;
    reg [3:0] next_cost;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            frontier_head <= 0;
            frontier_tail <= 0;
            frontier_count <= 0;
            min_settlers <= 0;
            done <= 0;
            possible <= 0;
            iron_reached <= 0;
            coal_reached <= 0;
            current_node <= 0;
            min_iron_cost <= 15;
            min_coal_cost <= 15;
            for (int i = 0; i < 8; i++) begin
                distance[i] <= 15;
                frontier[i] <= 0;
            end
        end else begin
            current_state <= next_state;
            if (current_state == EXPLORE && frontier_count > 0) begin
                current_node <= frontier[frontier_head];
                frontier_head <= (frontier_head + 1) % 8;
                frontier_count <= frontier_count - 1;
            end
        end
    end

    // State machine logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = EXPLORE;
                    // Initialize BFS
                    frontier[0] = 0; // Start at node 0 (cell 1)
                    frontier_head = 0;
                    frontier_tail = 1;
                    frontier_count = 1;
                    distance[0] = 0; // Starting node has 0 cost
                    min_iron_cost = 15;
                    min_coal_cost = 15;
                    iron_reached = 0;
                    coal_reached = 0;
                    done = 0;
                    possible = 0;
                end
            end
            EXPLORE: begin
                if (frontier_count == 0) begin
                    next_state = CHECK_PATHS;
                end else begin
                    // Process current node
                    if (iron_mask[current_node] && distance[current_node] < min_iron_cost) begin
                        min_iron_cost = distance[current_node];
                        iron_reached[current_node] = 1;
                    end
                    if (coal_mask[current_node] && distance[current_node] < min_coal_cost) begin
                        min_coal_cost = distance[current_node];
                        coal_reached[current_node] = 1;
                    end
                    
                    // Explore neighbors
                    for (int i = 0; i < 8; i++) begin
                        if (graph[current_node][i] && distance[i] > distance[current_node] + 1) begin
                            distance[i] = distance[current_node] + 1;
                            frontier[frontier_tail] = i;
                            frontier_tail = (frontier_tail + 1) % 8;
                            frontier_count = frontier_count + 1;
                        end
                    end
                end
            end
            CHECK_PATHS: begin
                // Find minimum combination of iron and coal costs
                if (min_iron_cost < 15 && min_coal_cost < 15) begin
                    min_settlers = min_iron_cost + min_coal_cost;
                    possible = 1;
                end else begin
                    min_settlers = 0;
                    possible = 0;
                end
                done = 1;
                next_state = COMPLETE;
            end
            COMPLETE: begin
                if (!start) begin
                    next_state = IDLE;
                    done = 0;
                end
            end
        endcase
    end

endmodule