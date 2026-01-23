module min_transmission_cost(
    input clk,
    input rst_n,
    input start,
    input [7:0] tree_a_nodes,
    input [7:0] tree_b_nodes,
    input [7:0] tree_a_adj [0:7],
    input [7:0] tree_b_adj [0:7],
    output reg [31:0] min_cost,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam COMPUTE_DIST_A = 3'b001;
    localparam COMPUTE_DIST_B = 3'b010;
    localparam FIND_CENTER_A = 3'b011;
    localparam FIND_CENTER_B = 3'b100;
    localparam CALCULATE_COST = 3'b101;
    localparam DONE_STATE = 3'b110;

    reg [2:0] state, next_state;
    
    // Registers for Floyd-Warshall
    reg [2:0] i, j, k; // iteration variables
    reg [2:0] node_idx, dist_idx, center_idx;
    
    // Distance matrices (using 3-bit for distances 0-7)
    reg [2:0] dist_a [0:7][0:7];
    reg [2:0] dist_b [0:7][0:7];
    
    // Center nodes and their distances
    reg [2:0] center_a, center_b;
    reg [2:0] center_dist_a, center_dist_b;
    
    // Accumulation registers
    reg [31:0] sum_sq_a, sum_sq_b;
    reg [31:0] temp_sum;
    reg [31:0] temp_cost;
    
    // Temporary calculation registers
    reg [9:0] sq_val; // 10-bit for squared value
    reg [31:0] mult_temp;
    reg [31:0] N, M;
    
    // Control flags
    reg dist_a_done, dist_b_done, center_a_done, center_b_done;
    reg calc_step;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            min_cost <= 0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = COMPUTE_DIST_A;
                else next_state = IDLE;
            end
            COMPUTE_DIST_A: begin
                if (dist_a_done) next_state = COMPUTE_DIST_B;
                else next_state = COMPUTE_DIST_A;
            end
            COMPUTE_DIST_B: begin
                if (dist_b_done) next_state = FIND_CENTER_A;
                else next_state = COMPUTE_DIST_B;
            end
            FIND_CENTER_A: begin
                if (center_a_done) next_state = FIND_CENTER_B;
                else next_state = FIND_CENTER_A;
            end
            FIND_CENTER_B: begin
                if (center_b_done) next_state = CALCULATE_COST;
                else next_state = FIND_CENTER_B;
            end
            CALCULATE_COST: begin
                if (calc_step) next_state = DONE_STATE;
                else next_state = CALCULATE_COST;
            end
            DONE_STATE: next_state = DONE_STATE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            i <= 0; j <= 0; k <= 0;
            node_idx <= 0; dist_idx <= 0; center_idx <= 0;
            center_a <= 0; center_b <= 0;
            center_dist_a <= 0; center_dist_b <= 0;
            sum_sq_a <= 0; sum_sq_b <= 0;
            temp_sum <= 0; temp_cost <= 0;
            sq_val <= 0; mult_temp <= 0;
            N <= 0; M <= 0;
            dist_a_done <= 0; dist_b_done <= 0;
            center_a_done <= 0; center_b_done <= 0;
            calc_step <= 0;
            done <= 0;
            min_cost <= 0;
            // Reset distance matrices
            for (int r = 0; r < 8; r++) begin
                for (int c = 0; c < 8; c++) begin
                    dist_a[r][c] <= 0;
                    dist_b[r][c] <= 0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        done <= 0;
                        dist_a_done <= 0;
                        dist_b_done <= 0;
                        center_a_done <= 0;
                        center_b_done <= 0;
                        calc_step <= 0;
                        i <= 0; j <= 0; k <= 0;
                        node_idx <= 0;
                        N <= tree_a_nodes;
                        M <= tree_b_nodes;
                        // Initialize dist_a from adjacency matrix
                        for (int r = 0; r < 8; r++) begin
                            for (int c = 0; c < 8; c++) begin
                                if (r == c)
                                    dist_a[r][c] <= 3'b000;
                                else if (tree_a_adj[r][c])
                                    dist_a[r][c] <= 3'b001;
                                else
                                    dist_a[r][c] <= 3'b111; // Initialize with large value (7)
                            end
                        end
                    end
                end
                
                COMPUTE_DIST_A: begin
                    // Floyd-Warshall for Tree A (simplified for 8 nodes)
                    // dist_a[k][j] = min(dist_a[k][j], dist_a[k][i] + dist_a[i][j])
                    if (i < 8) begin
                        if (j < 8) begin
                            if (k < 8) begin
                                if (dist_a[i][k] != 3'b111 && dist_a[k][j] != 3'b111) begin
                                    if (dist_a[i][j] > dist_a[i][k] + dist_a[k][j]) begin
                                        dist_a[i][j] <= dist_a[i][k] + dist_a[k][j];
                                    end
                                end
                                k <= k + 1;
                            end else begin
                                k <= 0;
                                j <= j + 1;
                            end
                        end else begin
                            j <= 0;
                            i <= i + 1;
                        end
                    end else begin
                        dist_a_done <= 1;
                    end
                end
                
                COMPUTE_DIST_B: begin
                    // Initialize dist_b if just starting
                    if (!dist_b_done && i == 0 && j == 0 && k == 0 && node_idx == 0) begin
                        for (int r = 0; r < 8; r++) begin
                            for (int c = 0; c < 8; c++) begin
                                if (r == c)
                                    dist_b[r][c] <= 3'b000;
                                else if (tree_b_adj[r][c])
                                    dist_b[r][c] <= 3'b001;
                                else
                                    dist_b[r][c] <= 3'b111;
                            end
                        end
                    end else begin
                        // Floyd-Warshall for Tree B
                        if (i < 8) begin
                            if (j < 8) begin
                                if (k < 8) begin
                                    if (dist_b[i][k] != 3'b111 && dist_b[k][j] != 3'b111) begin
                                        if (dist_b[i][j] > dist_b[i][k] + dist_b[k][j]) begin
                                            dist_b[i][j] <= dist_b[i][k] + dist_b[k][j];
                                        end
                                    end
                                    k <= k + 1;
                                end else begin
                                    k <= 0;
                                    j <= j + 1;
                                end
                            end else begin
                                j <= 0;
                                i <= i + 1;
                            end
                        end else begin
                            dist_b_done <= 1;
                        end
                    end
                end
                
                FIND_CENTER_A: begin
                    // Find center of Tree A: node with minimum sum of distances
                    if (node_idx < tree_a_nodes) begin
                        // Calculate sum of distances for current node
                        if (dist_idx < tree_a_nodes) begin
                            if (node_idx == dist_idx) begin
                                // Skip self (distance is 0)
                                dist_idx <= dist_idx + 1;
                            end else begin
                                temp_sum <= temp_sum + dist_a[node_idx][dist_idx];
                                dist_idx <= dist_idx + 1;
                            end
                        end else begin
                            // Check if this is the minimum so far
                            if (node_idx == 0 || temp_sum < sum_sq_a) begin
                                center_a <= node_idx;
                                sum_sq_a <= temp_sum;
                            end
                            temp_sum <= 0;
                            dist_idx <= 0;
                            node_idx <= node_idx + 1;
                        end
                    end else begin
                        // After finding center, get its distance sum for cost calculation
                        if (center_idx < tree_a_nodes) begin
                            if (center_a != center_idx) begin
                                center_dist_a <= center_dist_a + dist_a[center_a][center_idx];
                            end
                            center_idx <= center_idx + 1;
                        end else begin
                            center_a_done <= 1;
                            node_idx <= 0;
                            dist_idx <= 0;
                            center_idx <= 0;
                            temp_sum <= 0;
                            sum_sq_a <= 0;
                        end
                    end
                end
                
                FIND_CENTER_B: begin
                    // Find center of Tree B
                    if (node_idx < tree_b_nodes) begin
                        if (dist_idx < tree_b_nodes) begin
                            if (node_idx == dist_idx) begin
                                dist_idx <= dist_idx + 1;
                            end else begin
                                temp_sum <= temp_sum + dist_b[node_idx][dist_idx];
                                dist_idx <= dist_idx + 1;
                            end
                        end else begin
                            if (node_idx == 0 || temp_sum < sum_sq_b) begin
                                center_b <= node_idx;
                                sum_sq_b <= temp_sum;
                            end
                            temp_sum <= 0;
                            dist_idx <= 0;
                            node_idx <= node_idx + 1;
                        end
                    end else begin
                        if (center_idx < tree_b_nodes) begin
                            if (center_b != center_idx) begin
                                center_dist_b <= center_dist_b + dist_b[center_b][center_idx];
                            end
                            center_idx <= center_idx + 1;
                        end else begin
                            center_b_done <= 1;
                            // Reset for cost calculation
                            node_idx <= 0;
                            dist_idx <= 0;
                            center_idx <= 0;
                            sum_sq_a <= 0;
                            sum_sq_b <= 0;
                            temp_sum <= 0;
                        end
                    end
                end
                
                CALCULATE_COST: begin
                    // Calculate transmission cost in stages
                    if (!calc_step) begin
                        case (center_idx)
                            3'b000: begin
                                // Sum of squared distances in Tree A
                                if (node_idx < tree_a_nodes) begin
                                    if (dist_idx < tree_a_nodes) begin
                                        if (node_idx != dist_idx) begin
                                            sq_val <= dist_a[node_idx][dist_idx] * dist_a[node_idx][dist_idx];
                                        end
                                        dist_idx <= dist_idx + 1;
                                    end else begin
                                        node_idx <= node_idx + 1;
                                        dist_idx <= 0;
                                    end
                                end else begin
                                    sum_sq_a <= temp_sum;
                                    temp_sum <= 0;
                                    node_idx <= 0;
                                    dist_idx <= 0;
                                    center_idx <= 3'b001;
                                end
                            end
                            3'b001: begin
                                // Accumulate squared distances for A
                                if (node_idx < tree_a_nodes) begin
                                    if (dist_idx < tree_a_nodes) begin
                                        if (node_idx != dist_idx) begin
                                            temp_sum <= temp_sum + (dist_a[node_idx][dist_idx] * dist_a[node_idx][dist_idx]);
                                        end
                                        dist_idx <= dist_idx + 1;
                                    end else begin
                                        node_idx <= node_idx + 1;
                                        dist_idx <= 0;
                                    end
                                end else begin
                                    sum_sq_a <= temp_sum;
                                    temp_sum <= 0;
                                    node_idx <= 0;
                                    dist_idx <= 0;
                                    center_idx <= 3'b010;
                                end
                            end
                            3'b010: begin
                                // Sum of squared distances in Tree B
                                if (node_idx < tree_b_nodes) begin
                                    if (dist_idx < tree_b_nodes) begin
                                        if (node_idx != dist_idx) begin
                                            temp_sum <= temp_sum + (dist_b[node_idx][dist_idx] * dist_b[node_idx][dist_idx]);
                                        end
                                        dist_idx <= dist_idx + 1;
                                    end else begin
                                        node_idx <= node_idx + 1;
                                        dist_idx <= 0;
                                    end
                                end else begin
                                    sum_sq_b <= temp_sum;
                                    temp_sum <= 0;
                                    node_idx <= 0;
                                    center_idx <= 3'b011;
                                end
                            end
                            3'b011: begin
                                // Calculate final cost:
                                // Cost = sum_sq_a + sum_sq_b + N*M + N*M*(center_dist_a^2 + center_dist_b^2 + 2*center_dist_a*center_dist_b)
                                // = sum_sq_a + sum_sq_b + N*M*(1 + (center_dist_a + center_dist_b)^2)
                                // First compute center_dist_a^2 + center_dist_b^2 + 2*center_dist_a*center_dist_b
                                // = (center_dist_a + center_dist_b)^2
                                // temp_sum = (center_dist_a + center_dist_b)^2
                                temp_sum <= (center_dist_a + center_dist_b) * (center_dist_a + center_dist_b);
                                center_idx <= 3'b100;
                            end
                            3'b100: begin
                                // temp_sum = (center_dist_a + center_dist_b)^2 + 1
                                temp_sum <= temp_sum + 1;
                                center_idx <= 3'b101;
                            end
                            3'b101: begin
                                // Multiply by N*M: temp_sum = N*M * (1 + (center_dist_a + center_dist_b)^2)
                                mult_temp <= N * M * temp_sum;
                                center_idx <= 3'b110;
                            end
                            3'b110: begin
                                // Final: add sum_sq_a + sum_sq_b + mult_temp
                                temp_cost <= sum_sq_a + sum_sq_b + mult_temp;
                                center_idx <= 3'b111;
                            end
                            3'b111: begin
                                min_cost <= temp_cost;
                                calc_step <= 1;
                            end
                        endcase
                    end
                end
                
                DONE_STATE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule
