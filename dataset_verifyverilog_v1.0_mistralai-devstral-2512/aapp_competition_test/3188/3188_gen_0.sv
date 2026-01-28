module MSTCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire signed [15:0] coord_x [0:7],
    input wire signed [15:0] coord_y [0:7],
    input wire signed [15:0] coord_z [0:7],
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_EDGES = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] KRUN = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Edge structure: {weight[15:0], source[3:0], dest[3:0]}
    reg [31:0] edges [0:27];
    reg [31:0] sorted_edges [0:27];

    // Union-Find data structure
    reg [3:0] parent [0:7];
    reg [3:0] rank [0:7];

    // Counters and temporary registers
    reg [7:0] edge_count;
    reg [7:0] sort_i, sort_j;
    reg [7:0] krun_i;
    reg [7:0] mst_edges_added;
    reg [31:0] total_cost;

    reg [3:0] i_reg, j_reg;
    reg signed [15:0] dx, dy, dz;
    reg [15:0] min_diff;

    reg [3:0] find_temp, find_root;
    reg [3:0] u, v;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            edge_count <= 8'd0;
            sort_i <= 8'd0;
            sort_j <= 8'd0;
            krun_i <= 8'd0;
            mst_edges_added <= 8'd0;
            total_cost <= 32'd0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            dx <= 16'd0;
            dy <= 16'd0;
            dz <= 16'd0;
            min_diff <= 16'd0;
            find_temp <= 4'd0;
            find_root <= 4'd0;
            u <= 4'd0;
            v <= 4'd0;

            // Initialize edges
            integer k;
            for (k = 0; k < 28; k = k + 1) begin
                edges[k] <= 32'd0;
                sorted_edges[k] <= 32'd0;
            end

            // Initialize Union-Find
            integer p;
            for (p = 0; p < 8; p = p + 1) begin
                parent[p] <= p;
                rank[p] <= 4'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(posedge clk) begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    next_state <= CALC_EDGES;
                    edge_count <= 8'd0;
                    i_reg <= 4'd0;
                    j_reg <= 4'd1;
                    total_cost <= 32'd0;
                    mst_edges_added <= 8'd0;
                end else begin
                    next_state <= IDLE;
                end
            end

            CALC_EDGES: begin
                if (edge_count < (n - 4'd1) * n / 2) begin
                    // Calculate edge weight
                    dx <= coord_x[i_reg] - coord_x[j_reg];
                    dy <= coord_y[i_reg] - coord_y[j_reg];
                    dz <= coord_z[i_reg] - coord_z[j_reg];

                    // Absolute values
                    if (dx[15]) dx <= -dx;
                    if (dy[15]) dy <= -dy;
                    if (dz[15]) dz <= -dz;

                    // Find minimum
                    min_diff <= dx;
                    if (dy < min_diff) min_diff <= dy;
                    if (dz < min_diff) min_diff <= dz;

                    // Store edge: {weight, source, dest}
                    edges[edge_count] <= {min_diff, i_reg, j_reg};

                    // Update counters
                    edge_count <= edge_count + 8'd1;
                    if (j_reg == n - 4'd1) begin
                        i_reg <= i_reg + 4'd1;
                        j_reg <= i_reg + 4'd1;
                    end else begin
                        j_reg <= j_reg + 4'd1;
                    end
                end else begin
                    // Copy edges to sorted_edges for sorting
                    integer k;
                    for (k = 0; k < 28; k = k + 1) begin
                        sorted_edges[k] <= edges[k];
                    end
                    next_state <= SORT;
                    sort_i <= 8'd0;
                    sort_j <= 8'd0;
                end
            end

            SORT: begin
                // Bubble sort implementation
                if (sort_i < 27) begin
                    if (sort_j < 27 - sort_i) begin
                        // Compare and swap
                        if (sorted_edges[sort_j][31:16] > sorted_edges[sort_j + 8'd1][31:16]) begin
                            reg [31:0] temp;
                            temp <= sorted_edges[sort_j];
                            sorted_edges[sort_j] <= sorted_edges[sort_j + 8'd1];
                            sorted_edges[sort_j + 8'd1] <= temp;
                        end
                        sort_j <= sort_j + 8'd1;
                    end else begin
                        sort_j <= 8'd0;
                        sort_i <= sort_i + 8'd1;
                    end
                end else begin
                    next_state <= KRUN;
                    krun_i <= 8'd0;
                end
            end

            KRUN: begin
                if (mst_edges_added < n - 4'd1 && krun_i < 28) begin
                    // Extract edge
                    u <= sorted_edges[krun_i][15:0];
                    v <= sorted_edges[krun_i][31:16];

                    // Find root for u
                    find_temp <= u;
                    while (parent[find_temp] != find_temp) begin
                        find_temp <= parent[find_temp];
                    end
                    find_root <= find_temp;

                    // Find root for v
                    find_temp <= v;
                    while (parent[find_temp] != find_temp) begin
                        find_temp <= parent[find_temp];
                    end

                    // If different sets, union them
                    if (find_root != find_temp) begin
                        if (rank[find_root] < rank[find_temp]) begin
                            parent[find_root] <= find_temp;
                        end else if (rank[find_root] > rank[find_temp]) begin
                            parent[find_temp] <= find_root;
                        end else begin
                            parent[find_temp] <= find_root;
                            rank[find_root] <= rank[find_root] + 4'd1;
                        end

                        // Add edge weight to total cost
                        total_cost <= total_cost + sorted_edges[krun_i][31:16];
                        mst_edges_added <= mst_edges_added + 8'd1;
                    end

                    krun_i <= krun_i + 8'd1;
                end else begin
                    result <= total_cost;
                    next_state <= DONE_STATE;
                end
            end

            DONE_STATE: begin
                done <= 1'b1;
                next_state <= IDLE;
            end

            default: begin
                next_state <= IDLE;
                done <= 1'b0;
            end
        endcase
    end

endmodule