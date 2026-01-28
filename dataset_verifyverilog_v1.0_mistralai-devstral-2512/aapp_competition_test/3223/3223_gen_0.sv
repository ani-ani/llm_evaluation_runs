module ForestConstructor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] V,
    input wire [7:0] deg [0:15],
    output reg done,
    output reg possible,
    output reg [3:0] edges_a [0:14],
    output reg [3:0] edges_b [0:14],
    output reg [3:0] edge_count
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] VALIDATE = 3'd1;
    localparam [2:0] SORT_DEGS = 3'd2;
    localparam [2:0] GENERATE_EDGES = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Internal registers
    reg [3:0] vertex_count;
    reg [7:0] sorted_deg [0:15];
    reg [3:0] sorted_idx [0:15];
    reg [3:0] edge_a [0:14];
    reg [3:0] edge_b [0:14];
    reg [3:0] current_edge_count;
    reg [15:0] visited;
    reg [3:0] cycle_check_node;
    reg [3:0] cycle_check_parent;
    reg [3:0] cycle_check_current;
    reg [3:0] cycle_check_queue [0:15];
    reg [3:0] cycle_check_front;
    reg [3:0] cycle_check_rear;
    reg cycle_check_active;
    reg cycle_detected;
    reg [3:0] sort_i;
    reg [3:0] sort_j;
    reg [3:0] generate_i;
    reg [3:0] generate_j;
    reg [3:0] generate_k;
    reg [7:0] sum_deg;
    reg [3:0] num_components;
    reg [3:0] temp_deg [0:15];
    reg [3:0] temp_idx [0:15];
    reg [3:0] temp_edge_count;
    reg [3:0] temp_edge_a [0:14];
    reg [3:0] temp_edge_b [0:14];

    // Cycle check BFS
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            possible <= 1'b0;
            edge_count <= 4'd0;
            for (sort_i = 0; sort_i < 15; sort_i = sort_i + 1) begin
                edges_a[sort_i] <= 4'd0;
                edges_b[sort_i] <= 4'd0;
            end
            vertex_count <= 4'd0;
            sum_deg <= 8'd0;
            num_components <= 4'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            generate_i <= 4'd0;
            generate_j <= 4'd0;
            generate_k <= 4'd0;
            current_edge_count <= 4'd0;
            visited <= 16'd0;
            cycle_check_node <= 4'd0;
            cycle_check_parent <= 4'd0;
            cycle_check_current <= 4'd0;
            cycle_check_front <= 4'd0;
            cycle_check_rear <= 4'd0;
            cycle_check_active <= 1'b0;
            cycle_detected <= 1'b0;
            for (sort_i = 0; sort_i < 15; sort_i = sort_i + 1) begin
                cycle_check_queue[sort_i] <= 4'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            next_state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        next_state <= VALIDATE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                VALIDATE: begin
                    next_state <= SORT_DEGS;
                end

                SORT_DEGS: begin
                    if (sort_i == 4'd15) begin
                        next_state <= GENERATE_EDGES;
                    end else begin
                        next_state <= SORT_DEGS;
                    end
                end

                GENERATE_EDGES: begin
                    if (generate_i == 4'd15 || generate_j == 4'd15) begin
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= GENERATE_EDGES;
                    end
                end

                DONE_STATE: begin
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Validation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vertex_count <= 4'd0;
            sum_deg <= 8'd0;
            num_components <= 4'd0;
        end else if (state == VALIDATE) begin
            // Initialize
            vertex_count <= V;
            sum_deg <= 8'd0;
            num_components <= 4'd0;
            possible <= 1'b1;

            // Calculate sum of degrees
            for (sort_i = 0; sort_i < 16; sort_i = sort_i + 1) begin
                if (sort_i < vertex_count) begin
                    sum_deg <= sum_deg + deg[sort_i];
                    if (deg[sort_i] > 0) begin
                        num_components <= num_components + 4'd1;
                    end
                end
            end

            // Validation checks
            if (vertex_count == 4'd0) begin
                possible <= 1'b0;
            end else if (vertex_count == 4'd1) begin
                if (deg[0] != 8'd0) begin
                    possible <= 1'b0;
                end
            end else begin
                // Check sum is even
                if (sum_deg[0] != 1'b0) begin
                    possible <= 1'b0;
                end

                // Check max degree
                for (sort_i = 0; sort_i < vertex_count; sort_i = sort_i + 1) begin
                    if (deg[sort_i] > vertex_count - 4'd1) begin
                        possible <= 1'b0;
                    end
                end

                // Check forest feasibility
                if (sum_deg > 2 * (vertex_count - num_components)) begin
                    possible <= 1'b0;
                end
            end

            // Initialize sorted arrays
            for (sort_i = 0; sort_i < 16; sort_i = sort_i + 1) begin
                if (sort_i < vertex_count) begin
                    sorted_deg[sort_i] <= deg[sort_i];
                    sorted_idx[sort_i] <= sort_i + 4'd1; // 1-indexed
                end else begin
                    sorted_deg[sort_i] <= 8'd0;
                    sorted_idx[sort_i] <= 4'd0;
                end
            end

            // Initialize edge arrays
            for (sort_i = 0; sort_i < 15; sort_i = sort_i + 1) begin
                edge_a[sort_i] <= 4'd0;
                edge_b[sort_i] <= 4'd0;
            end
            current_edge_count <= 4'd0;

            // Initialize sort counters
            sort_i <= 4'd0;
            sort_j <= 4'd0;
        end
    end

    // Bubble sort
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sort_i <= 4'd0;
            sort_j <= 4'd0;
        end else if (state == SORT_DEGS) begin
            if (sort_i < 4'd15) begin
                if (sort_j < 4'd15 - sort_i) begin
                    // Compare and swap
                    if (sorted_deg[sort_j] < sorted_deg[sort_j + 4'd1]) begin
                        // Swap degrees
                        temp_deg[0] <= sorted_deg[sort_j];
                        sorted_deg[sort_j] <= sorted_deg[sort_j + 4'd1];
                        sorted_deg[sort_j + 4'd1] <= temp_deg[0];
                        
                        // Swap indices
                        temp_idx[0] <= sorted_idx[sort_j];
                        sorted_idx[sort_j] <= sorted_idx[sort_j + 4'd1];
                        sorted_idx[sort_j + 4'd1] <= temp_idx[0];
                    end
                    sort_j <= sort_j + 4'd1;
                end else begin
                    sort_j <= 4'd0;
                    sort_i <= sort_i + 4'd1;
                end
            end
        end
    end

    // Edge generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            generate_i <= 4'd0;
            generate_j <= 4'd0;
            generate_k <= 4'd0;
            cycle_check_active <= 1'b0;
            cycle_detected <= 1'b0;
            cycle_check_front <= 4'd0;
            cycle_check_rear <= 4'd0;
            visited <= 16'd0;
        end else if (state == GENERATE_EDGES && possible) begin
            if (!cycle_check_active) begin
                // Find next pair
                if (generate_i < 4'd15 && sorted_deg[generate_i] > 8'd0) begin
                    generate_j <= generate_i + 4'd1;
                    while (generate_j < 4'd15 && (sorted_deg[generate_j] == 8'd0 || generate_j == generate_i)) begin
                        generate_j <= generate_j + 4'd1;
                    end
                    
                    if (generate_j < 4'd15 && sorted_deg[generate_j] > 8'd0) begin
                        // Check if adding this edge would create a cycle
                        cycle_check_active <= 1'b1;
                        cycle_check_node <= sorted_idx[generate_i];
                        cycle_check_parent <= 4'd0;
                        cycle_check_current <= sorted_idx[generate_j];
                        visited <= 16'd0;
                        visited[sorted_idx[generate_i]] <= 1'b1;
                        visited[sorted_idx[generate_j]] <= 1'b1;
                        cycle_check_queue[0] <= sorted_idx[generate_j];
                        cycle_check_front <= 4'd0;
                        cycle_check_rear <= 4'd1;
                        cycle_detected <= 1'b0;
                        generate_k <= 4'd0;
                    end
                end
            end else begin
                // BFS cycle check
                if (cycle_check_front < cycle_check_rear) begin
                    cycle_check_current <= cycle_check_queue[cycle_check_front];
                    cycle_check_front <= cycle_check_front + 4'd1;
                    
                    // Check neighbors
                    for (generate_k = 0; generate_k < current_edge_count; generate_k = generate_k + 4'd1) begin
                        if (edge_a[generate_k] == cycle_check_current) begin
                            if (!visited[edge_b[generate_k]]) begin
                                visited[edge_b[generate_k]] <= 1'b1;
                                cycle_check_queue[cycle_check_rear] <= edge_b[generate_k];
                                cycle_check_rear <= cycle_check_rear + 4'd1;
                            end
                        end else if (edge_b[generate_k] == cycle_check_current) begin
                            if (!visited[edge_a[generate_k]]) begin
                                visited[edge_a[generate_k]] <= 1'b1;
                                cycle_check_queue[cycle_check_rear] <= edge_a[generate_k];
                                cycle_check_rear <= cycle_check_rear + 4'd1;
                            end
                        end
                    end
                    
                    // Check if we reached the start node
                    if (visited[cycle_check_node]) begin
                        cycle_detected <= 1'b1;
                    end
                    
                    // Check if queue is empty
                    if (cycle_check_front >= cycle_check_rear) begin
                        cycle_check_active <= 1'b0;
                        if (!cycle_detected) begin
                            // Add the edge
                            edge_a[current_edge_count] <= sorted_idx[generate_i];
                            edge_b[current_edge_count] <= sorted_idx[generate_j];
                            current_edge_count <= current_edge_count + 4'd1;
                            
                            // Decrement degrees
                            sorted_deg[generate_i] <= sorted_deg[generate_i] - 8'd1;
                            sorted_deg[generate_j] <= sorted_deg[generate_j] - 8'd1;
                        end
                        generate_i <= generate_i + 4'd1;
                    end
                end
            end
        end
    end

    // Output assignment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            edge_count <= 4'd0;
            for (sort_i = 0; sort_i < 15; sort_i = sort_i + 1) begin
                edges_a[sort_i] <= 4'd0;
                edges_b[sort_i] <= 4'd0;
            end
        end else if (state == DONE_STATE) begin
            done <= 1'b1;
            edge_count <= current_edge_count;
            for (sort_i = 0; sort_i < 15; sort_i = sort_i + 1) begin
                if (sort_i < current_edge_count) begin
                    edges_a[sort_i] <= edge_a[sort_i];
                    edges_b[sort_i] <= edge_b[sort_i];
                end else begin
                    edges_a[sort_i] <= 4'd0;
                    edges_b[sort_i] <= 4'd0;
                end
            end
        end else begin
            done <= 1'b0;
        end
    end

endmodule