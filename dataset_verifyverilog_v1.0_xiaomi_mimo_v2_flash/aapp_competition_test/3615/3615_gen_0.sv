module tower_coverage (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [15:0] x0, y0, x1, y1, x2, y2, x3, y3,
    input wire [15:0] x4, y4, x5, y5, x6, y6, x7, y7,
    output reg [7:0] result,
    output reg done
);

parameter COORD_WIDTH = 16;
parameter SQ_DIST_THRESH = 262144;
parameter MAX_TOWERS = 8;

// State definitions
localparam [3:0] S_IDLE = 4'd0;
localparam [3:0] S_RESET = 4'd1;
localparam [3:0] S_COMPUTE_DIST = 4'd2;
localparam [3:0] S_BUILD_COMPONENTS = 4'd3;
localparam [3:0] S_ASSIGN_COMPONENTS = 4'd4;
localparam [3:0] S_COMPUTE_MIN_DIST = 4'd5;
localparam [3:0] S_EVALUATE = 4'd6;
localparam [3:0] S_DONE = 4'd7;

reg [3:0] state, next_state;

// Storage for coordinates
reg [COORD_WIDTH-1:0] x_reg [0:MAX_TOWERS-1];
reg [COORD_WIDTH-1:0] y_reg [0:MAX_TOWERS-1];

// Union-Find arrays
reg [2:0] parent [0:MAX_TOWERS-1];
reg [3:0] size [0:MAX_TOWERS-1];

// Component assignment
reg [2:0] comp_id [0:MAX_TOWERS-1];
reg [3:0] comp_size [0:MAX_TOWERS-1];
reg [3:0] num_components;

// Distance matrix
reg [31:0] dist_sq [0:MAX_TOWERS-1][0:MAX_TOWERS-1];
reg edge_exists [0:MAX_TOWERS-1][0:MAX_TOWERS-1];

// Temporary variables
reg [3:0] i, j, k, m, n_idx;
reg [31:0] dx, dy, dx_sq, dy_sq;
reg [31:0] min_dist_sq;
reg [7:0] current_max;
reg [7:0] temp_total;
reg found_root;
reg [2:0] root_i, root_j;
reg [3:0] root_a, root_b;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done <= 0;
        result <= 0;
        i <= 0;
        j <= 0;
        k <= 0;
        m <= 0;
        n_idx <= 0;
        num_components <= 0;
        current_max <= 0;
        temp_total <= 0;
        dx <= 0;
        dy <= 0;
        dx_sq <= 0;
        dy_sq <= 0;
        min_dist_sq <= 0;
        root_i <= 0;
        root_j <= 0;
        found_root <= 0;
        // Initialize arrays
        for (i = 0; i < MAX_TOWERS; i = i + 1) begin
            x_reg[i] <= 0;
            y_reg[i] <= 0;
            parent[i] <= i;
            size[i] <= 1;
            comp_id[i] <= 0;
            comp_size[i] <= 0;
            for (j = 0; j < MAX_TOWERS; j = j + 1) begin
                edge_exists[i][j] <= 0;
                dist_sq[i][j] <= 0;
            end
        end
    end else begin
        state <= next_state;
    end
end

always @(*) begin
    case (state)
        S_IDLE: begin
            if (start) next_state = S_RESET;
            else next_state = S_IDLE;
        end
        S_RESET: next_state = S_COMPUTE_DIST;
        S_COMPUTE_DIST: begin
            if (i >= n_idx) next_state = S_BUILD_COMPONENTS;
            else next_state = S_COMPUTE_DIST;
        end
        S_BUILD_COMPONENTS: begin
            if (i >= n_idx) next_state = S_ASSIGN_COMPONENTS;
            else next_state = S_BUILD_COMPONENTS;
        end
        S_ASSIGN_COMPONENTS: next_state = S_COMPUTE_MIN_DIST;
        S_COMPUTE_MIN_DIST: begin
            if (i >= num_components) next_state = S_EVALUATE;
            else next_state = S_COMPUTE_MIN_DIST;
        end
        S_EVALUATE: next_state = S_DONE;
        S_DONE: next_state = S_DONE;
        default: next_state = S_IDLE;
    endcase
end

always @(posedge clk) begin
    if (!rst_n) begin
        // Already handled in reset block above
    end else begin
        case (state)
            S_RESET: begin
                // Initialize coordinates
                x_reg[0] <= x0; y_reg[0] <= y0;
                x_reg[1] <= x1; y_reg[1] <= y1;
                x_reg[2] <= x2; y_reg[2] <= y2;
                x_reg[3] <= x3; y_reg[3] <= y3;
                x_reg[4] <= x4; y_reg[4] <= y4;
                x_reg[5] <= x5; y_reg[5] <= y5;
                x_reg[6] <= x6; y_reg[6] <= y6;
                x_reg[7] <= x7; y_reg[7] <= y7;
                n_idx <= n;
                // Reset union-find
                for (i = 0; i < MAX_TOWERS; i = i + 1) begin
                    parent[i] <= i;
                    size[i] <= 1;
                    comp_id[i] <= 0;
                    comp_size[i] <= 0;
                    for (j = 0; j < MAX_TOWERS; j = j + 1) begin
                        edge_exists[i][j] <= 0;
                        dist_sq[i][j] <= 0;
                    end
                end
                i <= 0;
                j <= 0;
                num_components <= 0;
                current_max <= 0;
            end

            S_COMPUTE_DIST: begin
                if (i < n_idx) begin
                    if (j < n_idx) begin
                        if (i != j) begin
                            if (x_reg[i] > x_reg[j]) dx <= x_reg[i] - x_reg[j];
                            else dx <= x_reg[j] - x_reg[i];
                            if (y_reg[i] > y_reg[j]) dy <= y_reg[i] - y_reg[j];
                            else dy <= y_reg[j] - y_reg[i];
                            // Assume multiplication is combinational
                            dx_sq <= dx * dx;
                            dy_sq <= dy * dy;
                            dist_sq[i][j] <= dx_sq + dy_sq;
                            if (dx_sq + dy_sq <= SQ_DIST_THRESH) begin
                                edge_exists[i][j] <= 1;
                                edge_exists[j][i] <= 1;
                            end
                        end
                        j <= j + 1;
                    end else begin
                        j <= 0;
                        i <= i + 1;
                    end
                end
            end

            S_BUILD_COMPONENTS: begin
                if (i < n_idx) begin
                    if (j < n_idx) begin
                        if (edge_exists[i][j]) begin
                            // Find roots
                            root_a <= i;
                            while (parent[root_a] != root_a) root_a <= parent[root_a];
                            root_b <= j;
                            while (parent[root_b] != root_b) root_b <= parent[root_b];
                            // Union
                            if (root_a != root_b) begin
                                if (size[root_a] < size[root_b]) begin
                                    parent[root_a] <= root_b;
                                    size[root_b] <= size[root_b] + size[root_a];
                                end else begin
                                    parent[root_b] <= root_a;
                                    size[root_a] <= size[root_a] + size[root_b];
                                end
                            end
                        end
                        j <= j + 1;
                    end else begin
                        j <= 0;
                        i <= i + 1;
                    end
                end
            end

            S_ASSIGN_COMPONENTS: begin
                num_components <= 0;
                for (i = 0; i < n_idx; i = i + 1) begin
                    // Find root of i
                    root_i <= i;
                    while (parent[root_i] != root_i) root_i <= parent[root_i];
                    // Check if root already assigned
                    found_root = 0;
                    for (k = 0; k < num_components; k = k + 1) begin
                        if (comp_id[k] == root_i) begin
                            comp_size[k] <= comp_size[k] + 1;
                            found_root = 1;
                        end
                    end
                    if (!found_root) begin
                        comp_id[num_components] <= root_i;
                        comp_size[num_components] <= 1;
                        num_components <= num_components + 1;
                    end
                end
                i <= 0;
                j <= 0;
            end

            S_COMPUTE_MIN_DIST: begin
                if (i < num_components) begin
                    if (j < num_components) begin
                        if (i != j) begin
                            min_dist_sq <= 32'hFFFFFFFF;
                            for (m = 0; m < n_idx; m = m + 1) begin
                                for (k = 0; k < n_idx; k = k + 1) begin
                                    // Check if m is in component i and k in component j
                                    if (comp_id[m] == comp_id[i] && comp_id[k] == comp_id[j]) begin
                                        if (dist_sq[m][k] < min_dist_sq) begin
                                            min_dist_sq <= dist_sq[m][k];
                                        end
                                    end
                                end
                            end
                            if (min_dist_sq <= SQ_DIST_THRESH) begin
                                temp_total <= comp_size[i] + comp_size[j] + 8'd1;
                                if (comp_size[i] + comp_size[j] + 8'd1 > current_max) 
                                    current_max <= comp_size[i] + comp_size[j] + 8'd1;
                            end
                        end
                        j <= j + 1;
                    end else begin
                        j <= 0;
                        i <= i + 1;
                    end
                end
            end

            S_EVALUATE: begin
                for (i = 0; i < num_components; i = i + 1) begin
                    temp_total <= comp_size[i] + 8'd1;
                    if (comp_size[i] + 8'd1 > current_max) 
                        current_max <= comp_size[i] + 8'd1;
                end
                result <= current_max;
            end

            S_DONE: begin
                done <= 1;
            end
        endcase
    end
end

endmodule