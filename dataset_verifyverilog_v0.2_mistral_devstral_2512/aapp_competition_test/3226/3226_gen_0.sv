module police_escape (
    input clk,
    input rst_n,
    input start,
    input [1:0] num_nodes,
    input [1:0] num_exits,
    input [1:0] robber_start,
    input [1:0] police_start,
    input [5:0] edge_length [4:0][4:0],
    input [1:0] exits [1:0],
    output reg [31:0] min_speed,
    output reg done,
    output reg possible
);

    // Constants
    localparam IDLE = 3'b000;
    localparam LOAD_GRAPH = 3'b001;
    localparam COMPUTE_DIST_ROBBER = 3'b010;
    localparam COMPUTE_DIST_POLICE = 3'b011;
    localparam CHECK_EXITS = 3'b100;
    localparam CALCULATE_SPEED = 3'b101;
    localparam DONE = 3'b110;

    // Fixed-point constants
    localparam POLICE_SPEED = 32'h00A00000; // 160 * 65536 = 10485760
    localparam IMPOSSIBLE = 32'hFFFFFFFF;

    // State machine
    reg [2:0] state = IDLE;
    reg [9:0] cycle_count = 0;

    // Distance arrays (Q16.16 format)
    reg [31:0] dist_robber [0:3];
    reg [31:0] dist_police [0:3];

    // BFS queue and visited arrays
    reg [1:0] queue [0:3];
    reg [1:0] queue_head = 0;
    reg [1:0] queue_tail = 0;
    reg [1:0] queue_size = 0;
    reg [3:0] visited_robber = 0;
    reg [3:0] visited_police = 0;

    // Current node being processed
    reg [1:0] current_node = 0;

    // Temporary variables
    reg [31:0] temp_dist;
    reg [31:0] temp_speed;
    reg [31:0] min_speed_temp = IMPOSSIBLE;

    // Initialize distances to infinity
    integer i, j;
    initial begin
        for (i = 0; i < 4; i = i + 1) begin
            dist_robber[i] = IMPOSSIBLE;
            dist_police[i] = IMPOSSIBLE;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 0;
            done <= 0;
            possible <= 0;
            min_speed <= IMPOSSIBLE;
            queue_head <= 0;
            queue_tail <= 0;
            queue_size <= 0;
            visited_robber <= 0;
            visited_police <= 0;
            current_node <= 0;
            min_speed_temp <= IMPOSSIBLE;
            for (i = 0; i < 4; i = i + 1) begin
                dist_robber[i] <= IMPOSSIBLE;
                dist_police[i] <= IMPOSSIBLE;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD_GRAPH;
                        cycle_count <= 0;
                        done <= 0;
                        possible <= 0;
                        min_speed <= IMPOSSIBLE;
                        queue_head <= 0;
                        queue_tail <= 0;
                        queue_size <= 0;
                        visited_robber <= 0;
                        visited_police <= 0;
                        current_node <= 0;
                        min_speed_temp <= IMPOSSIBLE;
                        for (i = 0; i < 4; i = i + 1) begin
                            dist_robber[i] <= IMPOSSIBLE;
                            dist_police[i] <= IMPOSSIBLE;
                        end
                    end
                end

                LOAD_GRAPH: begin
                    // Initialize distances for robber and police starts
                    dist_robber[robber_start] <= 0;
                    dist_police[police_start] <= 0;
                    state <= COMPUTE_DIST_ROBBER;
                end

                COMPUTE_DIST_ROBBER: begin
                    // BFS for robber's distances
                    if (cycle_count == 0) begin
                        // Initialize queue with robber start
                        queue[0] <= robber_start;
                        queue_head <= 0;
                        queue_tail <= 1;
                        queue_size <= 1;
                        visited_robber <= (1 << robber_start);
                    end

                    if (queue_size > 0) begin
                        current_node <= queue[queue_head];
                        queue_head <= (queue_head + 1) % 4;
                        queue_size <= queue_size - 1;

                        // Explore neighbors
                        for (i = 0; i < num_nodes; i = i + 1) begin
                            if (edge_length[current_node][i] != 0 && !(visited_robber[i])) begin
                                temp_dist = dist_robber[current_node] + (edge_length[current_node][i] << 16);
                                if (temp_dist < dist_robber[i]) begin
                                    dist_robber[i] <= temp_dist;
                                    queue[queue_tail] <= i;
                                    queue_tail <= (queue_tail + 1) % 4;
                                    queue_size <= queue_size + 1;
                                    visited_robber <= visited_robber | (1 << i);
                                end
                            end
                        end
                    end

                    cycle_count <= cycle_count + 1;
                    if (cycle_count == 255) begin
                        state <= COMPUTE_DIST_POLICE;
                        cycle_count <= 0;
                        queue_head <= 0;
                        queue_tail <= 0;
                        queue_size <= 0;
                        visited_police <= 0;
                    end
                end

                COMPUTE_DIST_POLICE: begin
                    // BFS for police's distances
                    if (cycle_count == 0) begin
                        // Initialize queue with police start
                        queue[0] <= police_start;
                        queue_head <= 0;
                        queue_tail <= 1;
                        queue_size <= 1;
                        visited_police <= (1 << police_start);
                    end

                    if (queue_size > 0) begin
                        current_node <= queue[queue_head];
                        queue_head <= (queue_head + 1) % 4;
                        queue_size <= queue_size - 1;

                        // Explore neighbors
                        for (i = 0; i < num_nodes; i = i + 1) begin
                            if (edge_length[current_node][i] != 0 && !(visited_police[i])) begin
                                temp_dist = dist_police[current_node] + (edge_length[current_node][i] << 16);
                                if (temp_dist < dist_police[i]) begin
                                    dist_police[i] <= temp_dist;
                                    queue[queue_tail] <= i;
                                    queue_tail <= (queue_tail + 1) % 4;
                                    queue_size <= queue_size + 1;
                                    visited_police <= visited_police | (1 << i);
                                end
                            end
                        end
                    end

                    cycle_count <= cycle_count + 1;
                    if (cycle_count == 255) begin
                        state <= CHECK_EXITS;
                        cycle_count <= 0;
                    end
                end

                CHECK_EXITS: begin
                    // Check if robber and police start at same node
                    if (robber_start == police_start) begin
                        min_speed_temp <= IMPOSSIBLE;
                        possible <= 0;
                    end else begin
                        possible <= 0;
                        min_speed_temp <= IMPOSSIBLE;
                        for (i = 0; i < num_exits; i = i + 1) begin
                            if (dist_robber[exits[i]] != IMPOSSIBLE && dist_police[exits[i]] != IMPOSSIBLE) begin
                                // Calculate required speed: (dist_police * 160) / dist_robber
                                temp_speed = (dist_police[exits[i]] * POLICE_SPEED) / dist_robber[exits[i]];
                                if (temp_speed < min_speed_temp) begin
                                    min_speed_temp <= temp_speed;
                                    possible <= 1;
                                end
                            end
                        end
                    end
                    state <= CALCULATE_SPEED;
                end

                CALCULATE_SPEED: begin
                    min_speed <= min_speed_temp;
                    state <= DONE;
                end

                DONE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule