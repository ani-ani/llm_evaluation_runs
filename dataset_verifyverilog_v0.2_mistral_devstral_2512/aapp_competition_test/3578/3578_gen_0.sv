module airline_review_opt (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_nodes,
    input [2:0] num_req_edges,
    input [2:0] num_add_edges,
    input [3:0][7:0] req_edges_data,
    input [7:0][7:0] add_edges_data,
    output reg [23:0] min_cost,
    output reg done
);

    // Parameters
    localparam IDLE = 3'b000;
    localparam PRECOMP_PATHS = 3'b001;
    localparam DP_INIT = 3'b010;
    localparam DP_ITERATE = 3'b011;
    localparam DONE = 3'b100;

    // State
    reg [2:0] state = IDLE;

    // Shortest path matrix (8x8, 16-bit costs)
    reg [15:0] dist [0:7][0:7];

    // DP state (256 states, 16-bit costs)
    reg [15:0] dp [0:255];

    // Counters
    reg [2:0] k = 0;
    reg [2:0] i = 0;
    reg [2:0] j = 0;
    reg [7:0] mask = 0;
    reg [2:0] last = 0;

    // Required components
    reg [7:0] req_components = 0;
    reg [2:0] num_components = 0;

    // Temporary registers
    reg [15:0] temp_cost;
    reg [2:0] src, dst;
    reg [15:0] cost;

    // Initialize distances
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            min_cost <= 0;
        end else if (start) begin
            state <= PRECOMP_PATHS;
            done <= 0;
            // Initialize distance matrix
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    if (i == j) begin
                        dist[i][j] <= 0;
                    end else begin
                        dist[i][j] <= 16'hFFFF;
                    end
                end
            end
            // Add required edges
            for (i = 0; i < num_req_edges; i = i + 1) begin
                src = req_edges_data[i][7:6];
                dst = req_edges_data[i][5:4];
                cost = req_edges_data[i][3:0];
                if (dist[src][dst] > cost) begin
                    dist[src][dst] <= cost;
                end
            end
            // Add additional edges
            for (i = 0; i < num_add_edges; i = i + 1) begin
                src = add_edges_data[i][7:6];
                dst = add_edges_data[i][5:4];
                cost = add_edges_data[i][3:0];
                if (dist[src][dst] > cost) begin
                    dist[src][dst] <= cost;
                end
            end
            k <= 0;
            i <= 0;
            j <= 0;
        end
    end

    // Floyd-Warshall algorithm
    always @(posedge clk) begin
        if (state == PRECOMP_PATHS) begin
            if (k < num_nodes) begin
                if (i < num_nodes) begin
                    if (j < num_nodes) begin
                        // dist[i][j] = min(dist[i][j], dist[i][k] + dist[k][j])
                        if (dist[i][j] > (dist[i][k] + dist[k][j])) begin
                            dist[i][j] <= dist[i][k] + dist[k][j];
                        end
                        j <= j + 1;
                    end else begin
                        j <= 0;
                        i <= i + 1;
                    end
                end else begin
                    i <= 0;
                    k <= k + 1;
                end
            end else begin
                state <= DP_INIT;
                // Identify required components (simplified: all nodes with required edges)
                req_components <= 0;
                for (i = 0; i < num_req_edges; i = i + 1) begin
                    src = req_edges_data[i][7:6];
                    dst = req_edges_data[i][5:4];
                    req_components[src] <= 1;
                    req_components[dst] <= 1;
                end
                // Count components
                num_components <= 0;
                for (i = 0; i < 8; i = i + 1) begin
                    if (req_components[i]) begin
                        num_components <= num_components + 1;
                    end
                end
                // Initialize DP
                for (mask = 0; mask < 256; mask = mask + 1) begin
                    dp[mask] <= 16'hFFFF;
                end
                // Base case: starting at node 1 (Stockholm)
                dp[1 << 1] <= 0;
                mask <= 0;
                last <= 0;
            end
        end
    end

    // DP iteration
    always @(posedge clk) begin
        if (state == DP_INIT) begin
            state <= DP_ITERATE;
        end else if (state == DP_ITERATE) begin
            if (mask < 256) begin
                if (last < 8) begin
                    // Check if last is in mask and is a required component
                    if ((mask & (1 << last)) && req_components[last]) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            // Check if i is not in mask and is a required component
                            if (!(mask & (1 << i)) && req_components[i]) begin
                                temp_cost = dp[mask] + dist[last][i];
                                if (dp[mask | (1 << i)] > temp_cost) begin
                                    dp[mask | (1 << i)] <= temp_cost;
                                end
                            end
                        end
                    end
                    last <= last + 1;
                end else begin
                    last <= 0;
                    mask <= mask + 1;
                end
            end else begin
                // Find the minimum cost to return to Stockholm (node 1)
                min_cost <= 24'hFFFFFFFF;
                for (mask = 0; mask < 256; mask = mask + 1) begin
                    // Check if all required components are visited
                    if ((mask & req_components) == req_components) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            if (mask & (1 << i)) begin
                                temp_cost = dp[mask] + dist[i][1];
                                if (min_cost > temp_cost) begin
                                    min_cost <= temp_cost;
                                end
                            end
                        end
                    end
                end
                state <= DONE;
                done <= 1;
            end
        end
    end

endmodule