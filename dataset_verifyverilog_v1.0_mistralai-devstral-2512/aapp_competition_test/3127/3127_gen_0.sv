module SwitchPathAnalyzer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_nodes,
    input wire [3:0] src_id,
    input wire [3:0] dest_id,
    input wire [4:0] edge_count,
    input wire [3:0] edge_a [0:31],
    input wire [3:0] edge_b [0:31],
    input wire [9:0] edge_len [0:31],
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] PROCESS_NODE = 4'd2;
    localparam [3:0] RELAX_EDGES = 4'd3;
    localparam [3:0] BACKTRACE = 4'd4;
    localparam [3:0] OUTPUT = 4'd5;

    // Internal registers
    reg [3:0] state;
    reg [3:0] current_node;
    reg [3:0] next_node;
    reg [3:0] edge_index;
    reg [3:0] node_index;
    reg [3:0] cycle_count;
    reg [3:0] min_node;

    // Distance and hop arrays (16 nodes max)
    reg [31:0] dist [0:15];
    reg [4:0] hops [0:15];
    reg visited [0:15];

    // Backtrace arrays
    reg [3:0] pred [0:15];
    reg [3:0] pred_count [0:15];

    // Temporary registers
    reg [31:0] temp_dist;
    reg [4:0] temp_hops;
    reg [31:0] min_dist;

    // Cycle counter for timeout
    localparam [3:0] MAX_CYCLES = 4'd15;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_node <= 4'd0;
            next_node <= 4'd0;
            edge_index <= 4'd0;
            node_index <= 4'd0;
            cycle_count <= 4'd0;
            min_node <= 4'd0;
            result <= 16'hFFFF;
            done <= 1'b0;

            // Initialize arrays
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                dist[i] <= 32'd0;
                hops[i] <= 5'd0;
                visited[i] <= 1'b0;
                pred[i] <= 4'd0;
                pred_count[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize distance array
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i == src_id) begin
                            dist[i] <= 32'd0;
                            hops[i] <= 5'd0;
                        end else begin
                            dist[i] <= 32'd2147483647; // Max value
                            hops[i] <= 5'd31;
                        end
                        visited[i] <= 1'b0;
                        pred[i] <= 4'd0;
                        pred_count[i] <= 4'd0;
                    end

                    // Set source node as current
                    current_node <= src_id;
                    visited[src_id] <= 1'b1;
                    state <= PROCESS_NODE;
                end

                PROCESS_NODE: begin
                    // Find unvisited node with minimum distance
                    min_dist <= 32'd2147483647;
                    min_node <= 4'd0;
                    integer i;
                    for (i = 0; i < num_nodes; i = i + 1) begin
                        if (!visited[i] && dist[i] < min_dist) begin
                            min_dist <= dist[i];
                            min_node <= i;
                        end
                    end

                    // If no unvisited nodes or reached destination
                    if (min_dist == 32'd2147483647 || min_node == dest_id) begin
                        state <= BACKTRACE;
                    end else begin
                        current_node <= min_node;
                        visited[current_node] <= 1'b1;
                        edge_index <= 4'd0;
                        state <= RELAX_EDGES;
                    end
                end

                RELAX_EDGES: begin
                    // Process current edge
                    if (edge_index < edge_count) begin
                        // Check if edge connects to current node
                        if (edge_a[edge_index] == current_node) begin
                            next_node <= edge_b[edge_index];
                        end else if (edge_b[edge_index] == current_node) begin
                            next_node <= edge_a[edge_index];
                        end else begin
                            next_node <= 4'd0;
                        end

                        // Update distance if shorter path found
                        if (next_node != 4'd0 && !visited[next_node]) begin
                            temp_dist <= dist[current_node] + edge_len[edge_index];
                            temp_hops <= hops[current_node] + 5'd1;

                            if (temp_dist < dist[next_node] || 
                                (temp_dist == dist[next_node] && temp_hops < hops[next_node])) begin
                                dist[next_node] <= temp_dist;
                                hops[next_node] <= temp_hops;
                                pred[next_node] <= current_node;
                            end
                        end

                        edge_index <= edge_index + 4'd1;
                    end else begin
                        state <= PROCESS_NODE;
                    end
                end

                BACKTRACE: begin
                    // Mark nodes on shortest paths
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (dist[i] + dist[dest_id] == dist[dest_id] && 
                            hops[i] + hops[dest_id] == hops[dest_id]) begin
                            result[i] <= 1'b0;
                        end
                    end

                    // Ensure source and destination are marked
                    result[src_id] <= 1'b0;
                    result[dest_id] <= 1'b0;
                    state <= OUTPUT;
                end

                OUTPUT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase

            // Cycle counter for timeout
            if (cycle_count < MAX_CYCLES) begin
                cycle_count <= cycle_count + 4'd1;
            end else begin
                state <= IDLE;
                done <= 1'b1;
            end
        end
    end

endmodule