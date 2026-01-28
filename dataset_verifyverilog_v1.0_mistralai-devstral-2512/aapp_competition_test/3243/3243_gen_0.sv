module GraphConnectivityChecker(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_in,
    input wire [3:0] k_in,
    input wire [3:0] edge_u_in,
    input wire [3:0] edge_v_in,
    input wire edge_valid_in,
    input wire [3:0] deg_in [0:15],
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE    = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // DSU parent array (16x4-bit)
    reg [3:0] parent [0:15];
    reg [3:0] rank [0:15];

    // Degree counters
    reg [3:0] degree [0:15];

    // Edge storage (16 edges max)
    reg [3:0] edges_u [0:15];
    reg [3:0] edges_v [0:15];
    reg [3:0] edge_count;

    // Temporary variables
    reg [3:0] n_reg, k_reg;
    reg [3:0] components;
    reg [3:0] edges_to_remove;
    reg [3:0] total_edits;

    // DSU Find function with path compression
    function [3:0] dsu_find;
        input [3:0] x;
        reg [3:0] root;
        begin
            root = x;
            while (parent[root] != root) begin
                root = parent[root];
            end
            // Path compression
            while (parent[x] != root) begin
                parent[x] = root;
                x = parent[x];
            end
            dsu_find = root;
        end
    endfunction

    // DSU Union function
    function [3:0] dsu_union;
        input [3:0] x, y;
        reg [3:0] root_x, root_y;
        begin
            root_x = dsu_find(x);
            root_y = dsu_find(y);
            if (root_x == root_y) begin
                dsu_union = 1'b0; // No union performed
            end else begin
                if (rank[root_x] < rank[root_y]) begin
                    parent[root_x] = root_y;
                end else if (rank[root_x] > rank[root_y]) begin
                    parent[root_y] = root_x;
                end else begin
                    parent[root_y] = root_x;
                    rank[root_x] = rank[root_x] + 1'b1;
                end
                dsu_union = 1'b1; // Union performed
            end
        end
    endfunction

    // Initialize DSU
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            result <= 1'b0;
            done <= 1'b0;
            n_reg <= 4'd0;
            k_reg <= 4'd0;
            edge_count <= 4'd0;
            components <= 4'd0;
            edges_to_remove <= 4'd0;
            total_edits <= 4'd0;

            // Initialize DSU
            for (i = 0; i < 16; i = i + 1) begin
                parent[i] <= i;
                rank[i] <= 4'd0;
                degree[i] <= 4'd0;
            end

            // Initialize edge storage
            for (i = 0; i < 16; i = i + 1) begin
                edges_u[i] <= 4'd0;
                edges_v[i] <= 4'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n_in;
                        k_reg <= k_in;
                        next_state <= LOAD;
                    end
                end

                LOAD: begin
                    if (edge_valid_in && edge_count < 16) begin
                        // Store edge if valid (u < v)
                        if (edge_u_in < edge_v_in) begin
                            edges_u[edge_count] <= edge_u_in;
                            edges_v[edge_count] <= edge_v_in;
                            edge_count <= edge_count + 1'b1;
                        end
                    end

                    // Transition to compute when done loading
                    if (edge_count >= n_reg - 1 || cycle_count >= MAX_CYCLES - 100) begin
                        next_state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // Initialize DSU
                    for (i = 0; i < 16; i = i + 1) begin
                        parent[i] <= i;
                        rank[i] <= 4'd0;
                    end

                    // Process edges
                    for (i = 0; i < edge_count; i = i + 1) begin
                        dsu_union(edges_u[i], edges_v[i]);
                    end

                    // Count components
                    reg [3:0] component_map [0:15];
                    reg [3:0] comp_id;
                    components <= 4'd0;

                    for (i = 0; i < 16; i = i + 1) begin
                        component_map[i] <= dsu_find(i);
                    end

                    // Count unique components
                    reg [3:0] seen [0:15];
                    for (i = 0; i < 16; i = i + 1) begin
                        seen[i] <= 1'b0;
                    end

                    components <= 4'd0;
                    for (i = 0; i < n_reg; i = i + 1) begin
                        comp_id = component_map[i];
                        if (!seen[comp_id] && comp_id < n_reg) begin
                            seen[comp_id] <= 1'b1;
                            components <= components + 1'b1;
                        end
                    end

                    // Count degree violations
                    edges_to_remove <= 4'd0;
                    for (i = 0; i < n_reg; i = i + 1) begin
                        if (degree[i] > deg_in[i]) begin
                            edges_to_remove <= edges_to_remove + (degree[i] - deg_in[i]);
                        end
                    end

                    // Calculate total edits
                    total_edits <= (components - 1) + edges_to_remove;

                    // Check if within k
                    if (total_edits <= k_reg) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end

                    next_state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase

            // Cycle counter
            if (state != DONE) begin
                cycle_count <= cycle_count + 1'b1;
            end
        end
    end

    // Update degree counters during edge loading
    always @(posedge clk) begin
        if (state == LOAD && edge_valid_in && edge_u_in < edge_v_in) begin
            degree[edge_u_in] <= degree[edge_u_in] + 1'b1;
            degree[edge_v_in] <= degree[edge_v_in] + 1'b1;
        end
    end

endmodule