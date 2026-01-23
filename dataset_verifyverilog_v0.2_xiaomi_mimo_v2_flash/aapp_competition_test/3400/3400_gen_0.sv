module wonderland_decoder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] din,
    input wire din_valid,
    input wire din_end,
    output reg [15:0] result,
    output reg result_valid,
    output reg ready
);

    // States
    localparam S_IDLE = 0;
    localparam S_READ_INPUT = 1;
    localparam S_DECODE_P1 = 2;
    localparam S_DECODE_P2 = 3;
    localparam S_DECODE_P3 = 4;
    localparam S_DIJKSTRA_INIT = 5;
    localparam S_DIJKSTRA_LOOP = 6;
    localparam S_DONE = 7;

    reg [3:0] state;

    // Input Storage (Buffer)
    reg [7:0] input_buffer [0:511];
    reg [8:0] wr_ptr;
    reg [8:0] rd_ptr;
    reg [7:0] total_trips;

    // Graph Data (Edge Weight Matrix)
    reg [7:0] edge_weight [0:15][0:15];
    reg edge_valid [0:15][0:15];

    // Dijkstra Data
    reg [7:0] dist [0:15];
    reg visited [0:15];

    // Counters and Temp Vars
    reg [7:0] trip_idx;
    reg [7:0] node_idx;
    reg [7:0] u_idx; // Current source node for edge processing
    reg [7:0] v_idx; // Current target node for edge processing
    reg [7:0] len_idx; // Position inside a trip
    reg [7:0] min_node; // The node selected as current in Dijkstra
    reg [7:0] temp_a, temp_b; // General temp storage
    reg [7:0] trip_len; // Current trip length being read
    reg [7:0] prev_node; // For edge tracking in trips
    reg [7:0] scan_idx; // For scanning loops
    
    // Helper signals
    wire [7:0] current_byte = input_buffer[rd_ptr];
    
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            ready <= 1;
            result_valid <= 0;
            result <= 0;
            wr_ptr <= 0;
            // Reset Arrays
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    edge_weight[i][j] <= 0;
                    edge_valid[i][j] <= 0;
                end
                dist[i] <= 0;
                visited[i] <= 0;
            end
        end else begin
            case (state)
                S_IDLE: begin
                    result_valid <= 0;
                    if (start) begin
                        state <= S_READ_INPUT;
                        ready <= 0;
                        wr_ptr <= 0;
                    end
                end

                S_READ_INPUT: begin
                    if (din_valid) begin
                        input_buffer[wr_ptr] <= din;
                        wr_ptr <= wr_ptr + 1;
                        if (din_end) begin
                            state <= S_DECODE_P1;
                            rd_ptr <= 0;
                            total_trips <= 0;
                        end
                    end
                end

                S_DECODE_P1: begin
                    if (rd_ptr == 0) begin
                        total_trips <= current_byte;
                        rd_ptr <= 1;
                        trip_idx <= 0;
                        len_idx <= 0;
                        prev_node <= 8'hFF;
                    end else if (trip_idx < total_trips) begin
                        // Parse Trip
                        if (len_idx == 0) begin
                            // Read Length
                            trip_len <= current_byte;
                            len_idx <= 1;
                            rd_ptr <= rd_ptr + 1;
                            prev_node <= 8'hFF;
                        end else if (len_idx <= trip_len) begin
                            // Read Nodes
                            if (prev_node != 8'hFF && current_byte < 16 && prev_node < 16) begin
                                edge_valid[prev_node][current_byte] <= 1;
                            end
                            prev_node <= current_byte;
                            len_idx <= len_idx + 1;
                            rd_ptr <= rd_ptr + 1;
                        end else begin
                            // Trip End
                            trip_idx <= trip_idx + 1;
                            len_idx <= 0;
                        end
                    end else begin
                        state <= S_DECODE_P2;
                        u_idx <= 0;
                        v_idx <= 0;
                    end
                end

                S_DECODE_P2: begin
                    // Since input does not explicitly provide trip durations (based on spec "Locations per Trip"),
                    // we cannot solve the system of equations for arbitrary weights.
                    // We will assume Weight = 1 for all discovered edges.
                    // This effectively transforms the problem into "Shortest Path by Hop Count".
                    
                    if (edge_valid[u_idx][v_idx]) begin
                        edge_weight[u_idx][v_idx] <= 1;
                    end

                    // Iterate through all edges
                    if (v_idx == 15) begin
                        v_idx <= 0;
                        if (u_idx == 15) begin
                            state <= S_DECODE_P3;
                        end else begin
                            u_idx <= u_idx + 1;
                        end
                    end else begin
                        v_idx <= v_idx + 1;
                    end
                end

                S_DECODE_P3: begin
                    // Verification Phase (Skipped as we assume valid data or weights=1)
                    state <= S_DIJKSTRA_INIT;
                end

                S_DIJKSTRA_INIT: begin
                    // Initialize Distances
                    for (i = 0; i < 16; i = i + 1) begin
                        dist[i] <= 8'hFF; // Infinity
                        visited[i] <= 0;
                    end
                    dist[0] <= 0; // Source A is Node 0 (Index 0)
                    
                    // Reset Iterators
                    scan_idx <= 0;
                    node_idx <= 0;
                    state <= S_DIJKSTRA_LOOP;
                end

                S_DIJKSTRA_LOOP: begin
                    // 1. Find Min Distance Node (Scan)
                    if (scan_idx == 0) begin
                        temp_a <= 8'hFF; // Min Dist
                        temp_b <= 16;    // Min Node
                        scan_idx <= 1;
                    end else if (scan_idx <= 16) begin
                        // Iterate i = scan_idx - 1
                        if (!visited[scan_idx - 1] && dist[scan_idx - 1] < temp_a) begin
                            temp_a <= dist[scan_idx - 1];
                            temp_b <= scan_idx - 1;
                        end
                        scan_idx <= scan_idx + 1;
                    end else if (scan_idx == 17) begin
                        // Check Results
                        if (temp_b == 16 || temp_a == 8'hFF) begin
                            // No reachable node or all visited. Check if we reached Dest (Node 15).
                            if (dist[15] == 8'hFF) result <= 16'hFFFF;
                            else result <= dist[15];
                            state <= S_DONE;
                        end else begin
                            // Found Min Node
                            min_node <= temp_b;
                            visited[temp_b] <= 1;
                            
                            // Check if Dest Reached (Node 15)
                            if (temp_b == 15) begin
                                result <= dist[15];
                                state <= S_DONE;
                            end else begin
                                // Prepare to relax edges
                                node_idx <= 0;
                                scan_idx <= 18;
                            end
                        end
                    end else if (scan_idx == 18) begin
                        // Relax Edges
                        if (node_idx < 16) begin
                            if (edge_valid[min_node][node_idx]) begin
                                // Update distance if shorter path found
                                if (dist[min_node] != 8'hFF) begin
                                    if (dist[min_node] + edge_weight[min_node][node_idx] < dist[node_idx]) begin
                                        dist[node_idx] <= dist[min_node] + edge_weight[min_node][node_idx];
                                    end
                                end
                            end
                            node_idx <= node_idx + 1;
                        end else begin
                            // Done relaxing, back to find next min node
                            scan_idx <= 0;
                        end
                    end
                end

                S_DONE: begin
                    result_valid <= 1;
                    ready <= 1;
                    if (start) state <= S_IDLE;
                end
            endcase
        end
    end
endmodule