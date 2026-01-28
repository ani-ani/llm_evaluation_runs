module FindMaxClique(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] sensor_x [0:7],
    input wire [15:0] sensor_y [0:7],
    input wire [15:0] d,
    output reg done,
    output reg [3:0] size,
    output reg [31:0] indices
);

    localparam MAX_N = 8;
    localparam COORD_BITS = 16;
    localparam DIST_BITS = 16;
    localparam MAX_CYCLES = 256;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ_COORDS = 3'd1;
    localparam [2:0] COMPUTE_ADJ = 3'd2;
    localparam [2:0] FIND_CLIQUE = 3'd3;
    localparam [2:0] UPDATE_MAX = 3'd4;
    localparam [2:0] FINISH = 3'd5;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    reg [2:0] n;  // Number of active sensors (0-8)
    
    // Internal storage for coordinates
    reg [15:0] x_reg [0:7];
    reg [15:0] y_reg [0:7];
    
    // Adjacency matrix (packed as 8x8 bits in 8x16-bit array for easier access)
    reg [15:0] adj [0:7];  // adj[i][j] = bit j of adj[i]
    
    // Clique search variables
    reg [7:0] subset_mask;  // Current subset to check
    reg [2:0] subset_size;  // Size of current subset
    reg [2:0] i_idx, j_idx;  // Iteration indices
    reg [7:0] clique_mask;  // Valid clique members
    reg is_clique;
    
    // Best result tracking
    reg [3:0] best_size;
    reg [7:0] best_mask;
    reg [7:0] d_squared_reg;  // d^2 in Q8.8 format (use lower 16 bits)
    
    // Temporary for distance computation
    reg [15:0] diff_x, diff_y;
    reg [31:0] sq_diff_x, sq_diff_y;
    reg [31:0] sum_sq;
    
    integer temp_idx;
    reg [3:0] bit_pos;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            size <= 4'd0;
            indices <= 32'd0;
            cycle_count <= 8'd0;
            n <= 3'd0;
            best_size <= 4'd0;
            best_mask <= 8'd0;
            d_squared_reg <= 16'd0;
            // Initialize arrays
            for (temp_idx = 0; temp_idx < 8; temp_idx = temp_idx + 1) begin
                x_reg[temp_idx] <= 16'd0;
                y_reg[temp_idx] <= 16'd0;
                adj[temp_idx] <= 16'd0;
            end
            subset_mask <= 8'd0;
            subset_size <= 3'd0;
            i_idx <= 3'd0;
            j_idx <= 3'd0;
            clique_mask <= 8'd0;
            is_clique <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    size <= 4'd0;
                    indices <= 32'd0;
                    cycle_count <= 8'd0;
                    best_size <= 4'd0;
                    best_mask <= 8'd0;
                    if (start) begin
                        // Read number of active sensors (count non-zero x coordinates)
                        n <= 3'd0;
                        for (temp_idx = 0; temp_idx < 8; temp_idx = temp_idx + 1) begin
                            if (sensor_x[temp_idx] != 16'd0) begin
                                n <= n + 3'd1;
                            end
                        end
                        // If n=0, treat as n=1 (edge case)
                        if (n == 3'd0) n <= 3'd1;
                        // Compute d^2
                        d_squared_reg <= d * d[15:8];  // Simplified: d^2 shifted
                        state <= READ_COORDS;
                        temp_idx <= 0;
                    end
                end
                
                READ_COORDS: begin
                    if (temp_idx < 8) begin
                        x_reg[temp_idx] <= sensor_x[temp_idx];
                        y_reg[temp_idx] <= sensor_y[temp_idx];
                        temp_idx <= temp_idx + 1;
                    end else begin
                        state <= COMPUTE_ADJ;
                        i_idx <= 3'd0;
                        j_idx <= 3'd0;
                        // Reset adjacency matrix
                        for (temp_idx = 0; temp_idx < 8; temp_idx = temp_idx + 1) begin
                            adj[temp_idx] <= 16'd0;
                        end
                    end
                end
                
                COMPUTE_ADJ: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i_idx < n) begin
                        if (j_idx < n) begin
                            if (i_idx != j_idx) begin
                                // Compute squared distance
                                diff_x <= (x_reg[i_idx] > x_reg[j_idx]) ? (x_reg[i_idx] - x_reg[j_idx]) : (x_reg[j_idx] - x_reg[i_idx]);
                                diff_y <= (y_reg[i_idx] > y_reg[j_idx]) ? (y_reg[i_idx] - y_reg[j_idx]) : (y_reg[j_idx] - y_reg[i_idx]);
                                // Wait one cycle for subtraction
                            end
                            j_idx <= j_idx + 3'd1;
                        end else begin
                            j_idx <= 3'd0;
                            i_idx <= i_idx + 3'd1;
                        end
                    end else if (i_idx == n && j_idx == 3'd0) begin
                        // Compute squares and store (back to j_idx loop)
                        i_idx <= 3'd0;
                        j_idx <= 3'd0;
                    end else begin
                        // Check if done computing adj
                        if (cycle_count >= MAX_CYCLES) begin
                            state <= FINISH;
                        end else begin
                            state <= FIND_CLIQUE;
                            subset_size <= 3'd1;
                            subset_mask <= 8'b00000001;  // Start with first subset
                            i_idx <= 3'd0;
                        end
                    end
                    // Compute squared diff for current (i_idx, j_idx-1)
                    if (j_idx > 3'd0 && i_idx < n && (j_idx - 3'd1) < n) begin
                        if ((j_idx - 3'd1) != i_idx) begin
                            sq_diff_x <= {16'd0, diff_x} * {16'd0, diff_x};  // 16x16 -> 32 bit
                            sq_diff_y <= {16'd0, diff_y} * {16'd0, diff_y};
                            sum_sq <= (sq_diff_x + sq_diff_y);
                            // Adj if distance^2 <= d^2
                            if (sum_sq <= {16'd0, d_squared_reg}) begin
                                adj[i_idx] <= adj[i_idx] | (1 << (j_idx - 3'd1));
                            end
                        end
                    end
                end
                
                FIND_CLIQUE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Check if current subset is a clique
                    if (subset_size == 3'd1) begin
                        // Single node is always a clique
                        is_clique <= 1'b1;
                        clique_mask <= subset_mask;
                        state <= UPDATE_MAX;
                    end else begin
                        // Check all pairs in subset
                        if (i_idx < 8) begin
                            if (subset_mask[i_idx]) begin
                                if (j_idx < 8) begin
                                    if (j_idx != i_idx && subset_mask[j_idx]) begin
                                        // Check adjacency
                                        if (adj[i_idx][j_idx]) begin
                                            is_clique <= 1'b1;
                                        end else begin
                                            is_clique <= 1'b0;
                                            j_idx <= 8;  // Force exit
                                        end
                                    end
                                    j_idx <= j_idx + 3'd1;
                                end else begin
                                    j_idx <= 3'd0;
                                    i_idx <= i_idx + 3'd1;
                                end
                            end else begin
                                i_idx <= i_idx + 3'd1;
                            end
                        end else begin
                            // Done checking, is_clique still holds
                            if (is_clique) begin
                                clique_mask <= subset_mask;
                                state <= UPDATE_MAX;
                            end else begin
                                state <= UPDATE_MAX;  // Will not update
                            end
                        end
                    end
                end
                
                UPDATE_MAX: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (is_clique && subset_size > best_size) begin
                        best_size <= subset_size;
                        best_mask <= clique_mask;
                    end
                    is_clique <= 1'b0;
                    // Generate next subset
                    // Simple method: increment mask and count bits
                    if (subset_mask < (1 << n)) begin
                        subset_mask <= subset_mask + 8'd1;
                        // Count bits in new mask
                        bit_pos <= 4'd0;
                        subset_size <= 3'd0;
                        for (temp_idx = 0; temp_idx < 8; temp_idx = temp_idx + 1) begin
                            if (subset_mask[temp_idx]) subset_size <= subset_size + 3'd1;
                        end
                        i_idx <= 3'd0;
                        j_idx <= 3'd0;
                        state <= FIND_CLIQUE;
                    end else begin
                        // All subsets checked
                        state <= FINISH;
                    end
                    // Early exit if found perfect clique
                    if (best_size == n) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    size <= best_size;
                    // Pack indices
                    indices <= 32'd0;
                    bit_pos <= 4'd0;
                    for (temp_idx = 0; temp_idx < 8; temp_idx = temp_idx + 1) begin
                        if (best_mask[temp_idx]) begin
                            indices[bit_pos*4 +: 4] <= temp_idx[3:0] + 4'd1;  // 1-based
                            bit_pos <= bit_pos + 4'd1;
                        end
                    end
                    // Check for next start
                    if (start) begin
                        done <= 1'b0;
                        state <= IDLE;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        // Timeout protection
                        done <= 1'b1;
                    end
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule