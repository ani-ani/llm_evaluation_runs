module FlightPlaneCalculator(
    input clk,
    input rst_n,
    input start,
    input [31:0] flight_params [0:3],
    input [15:0] flight_times [0:3],
    input [15:0] dist_matrix [0:15],
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] BUILD_GRAPH = 3'd2;
    localparam [2:0] COMPUTE_FLOW = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    reg [2:0] state, next_state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd4000;

    // Flight data extraction
    reg [3:0] flight_s [0:3];
    reg [3:0] flight_f [0:3];
    reg [15:0] flight_t [0:3];
    reg [7:0] flight_id [0:3];

    // Graph parameters
    localparam [3:0] MAX_FLIGHTS = 4'd4;
    localparam [4:0] MAX_NODES = 5'd10; // 2*4 + 2
    localparam [4:0] SOURCE = 5'd0;
    localparam [4:0] SINK = 5'd9;

    // Graph representation
    reg [4:0] edge_from [0:19];
    reg [4:0] edge_to [0:19];
    reg [7:0] edge_cap [0:19];
    reg [7:0] edge_flow [0:19];
    reg [4:0] edge_count;

    // Dinic's algorithm variables
    reg [4:0] level [0:9];
    reg [4:0] ptr [0:9];
    reg [7:0] max_flow;

    // Temporary variables
    reg [3:0] i, j, k;
    reg [4:0] u, v;
    reg [7:0] temp_cap;
    reg [15:0] temp_time;
    reg [15:0] temp_dist;
    reg can_connect;

    // Extract flight parameters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 4; i = i + 1) begin
                flight_s[i] <= 4'd0;
                flight_f[i] <= 4'd0;
                flight_t[i] <= 16'd0;
                flight_id[i] <= 8'd0;
            end
        end else if (state == INIT) begin
            for (i = 0; i < 4; i = i + 1) begin
                flight_s[i] <= flight_params[i][3:0];
                flight_f[i] <= flight_params[i][7:4];
                flight_t[i] <= flight_params[i][23:8];
                flight_id[i] <= flight_params[i][31:24];
            end
        end
    end

    // Build graph
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge_count <= 5'd0;
            for (i = 0; i < 20; i = i + 1) begin
                edge_from[i] <= 5'd0;
                edge_to[i] <= 5'd0;
                edge_cap[i] <= 8'd0;
                edge_flow[i] <= 8'd0;
            end
        end else if (state == BUILD_GRAPH) begin
            // Add source edges
            for (i = 0; i < 4; i = i + 1) begin
                edge_from[edge_count] <= SOURCE;
                edge_to[edge_count] <= i + 1;
                edge_cap[edge_count] <= 8'd1;
                edge_flow[edge_count] <= 8'd0;
                edge_count <= edge_count + 1;
            end

            // Add sink edges
            for (i = 0; i < 4; i = i + 1) begin
                edge_from[edge_count] <= i + 5;
                edge_to[edge_count] <= SINK;
                edge_cap[edge_count] <= 8'd1;
                edge_flow[edge_count] <= 8'd0;
                edge_count <= edge_count + 1;
            end

            // Add flight connection edges
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    // Check if flight j can follow flight i
                    temp_time <= flight_t[i] + flight_times[flight_f[i]];
                    temp_dist <= dist_matrix[flight_f[i] * 4 + flight_s[j]];
                    can_connect <= (temp_time + temp_dist) <= flight_t[j];

                    if (can_connect) begin
                        edge_from[edge_count] <= i + 1;
                        edge_to[edge_count] <= j + 5;
                        edge_cap[edge_count] <= 8'd1;
                        edge_flow[edge_count] <= 8'd0;
                        edge_count <= edge_count + 1;
                    end
                end
            end

            state <= COMPUTE_FLOW;
        end
    end

    // Dinic's algorithm - BFS for level graph
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 10; i = i + 1) begin
                level[i] <= 5'd0;
                ptr[i] <= 5'd0;
            end
            max_flow <= 8'd0;
        end else if (state == COMPUTE_FLOW) begin
            // Initialize levels
            for (i = 0; i < 10; i = i + 1) begin
                level[i] <= 5'd0;
            end
            level[SOURCE] <= 5'd1;

            // BFS queue
            reg [4:0] queue [0:9];
            reg [3:0] q_head, q_tail;
            q_head <= 4'd0;
            q_tail <= 4'd1;
            queue[0] <= SOURCE;

            while (q_head < q_tail) begin
                u <= queue[q_head];
                q_head <= q_head + 1;

                for (i = 0; i < edge_count; i = i + 1) begin
                    if (edge_from[i] == u && edge_flow[i] < edge_cap[i]) begin
                        v <= edge_to[i];
                        if (level[v] == 5'd0) begin
                            level[v] <= level[u] + 5'd1;
                            queue[q_tail] <= v;
                            q_tail <= q_tail + 1;
                        end
                    end
                end
            end

            // If sink not reached, we're done
            if (level[SINK] == 5'd0) begin
                state <= FINISH;
            end else begin
                // Initialize pointers
                for (i = 0; i < 10; i = i + 1) begin
                    ptr[i] <= 5'd0;
                end

                // DFS to find blocking flow
                reg [7:0] flow;
                reg [4:0] stack [0:9];
                reg [3:0] stack_ptr;
                stack_ptr <= 4'd0;
                stack[0] <= SOURCE;

                while (stack_ptr >= 0) begin
                    u <= stack[stack_ptr];

                    if (u == SINK) begin
                        // Found a path, compute bottleneck
                        flow <= 8'd1; // Since all capacities are 1
                        max_flow <= max_flow + flow;

                        // Update flow along path
                        for (i = 0; i < stack_ptr; i = i + 1) begin
                            for (j = 0; j < edge_count; j = j + 1) begin
                                if (edge_from[j] == stack[i] && edge_to[j] == stack[i+1]) begin
                                    edge_flow[j] <= edge_flow[j] + flow;
                                end
                            end
                        end

                        // Backtrack
                        stack_ptr <= stack_ptr - 1;
                    end else begin
                        // Find next edge
                        reg found;
                        found <= 1'b0;
                        for (i = ptr[u]; i < edge_count; i = i + 1) begin
                            if (edge_from[i] == u && edge_flow[i] < edge_cap[i] && 
                                level[edge_to[i]] == level[u] + 5'd1) begin
                                ptr[u] <= i + 1;
                                stack_ptr <= stack_ptr + 1;
                                stack[stack_ptr] <= edge_to[i];
                                found <= 1'b1;
                                break;
                            end
                        end

                        if (!found) begin
                            stack_ptr <= stack_ptr - 1;
                        end
                    end
                end

                // Check if we need another BFS
                if (max_flow < 4'd4) begin
                    state <= COMPUTE_FLOW;
                end else begin
                    state <= FINISH;
                end
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    next_state <= BUILD_GRAPH;
                end

                BUILD_GRAPH: begin
                    next_state <= COMPUTE_FLOW;
                end

                COMPUTE_FLOW: begin
                    cycle_count <= cycle_count + 1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end else begin
                        next_state <= COMPUTE_FLOW;
                    end
                end

                FINISH: begin
                    result <= 8'd4 - max_flow;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
            state <= next_state;
        end
    end

endmodule