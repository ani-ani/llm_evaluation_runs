module absorbing_markov_chain(
    input clk,
    input rst_n,
    input start,
    input [7:0] adj_0, adj_1, adj_2, adj_3, adj_4, adj_5, adj_6, adj_7,
    input [3:0] start_s,
    input [3:0] start_t,
    input [3:0] n,
    output reg [31:0] expected_time,
    output reg done,
    output reg never_meet
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_MATRIX = 3'd1;
    localparam [2:0] INIT_VALUES = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] CHECK_CONVERGENCE = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;
    
    // Constants
    localparam [15:0] Q16_SCALE = 16'h10000;  // 2^16 for Q16.16
    localparam [31:0] THRESHOLD = 32'd256;     // Convergence threshold (1/256)
    localparam [7:0] MAX_ITER = 8'd100;        // Max iterations
    
    // Registers
    reg [2:0] state, next_state;
    reg [7:0] adj_matrix [0:7][0:7];          // 8x8 binary adjacency matrix
    reg [2:0] i, j;                           // Loop counters
    reg [2:0] node_s, node_t;                 // Current positions
    reg [31:0] E [0:63];                      // Expected time for each pair (i,j)
    reg [31:0] E_next [0:63];                 // Next iteration values
    reg [31:0] temp_sum;                      // Accumulator for sum
    reg [7:0] deg_i, deg_j;                   // Degrees of nodes
    reg [7:0] pair_idx;                       // Index for pair (i,j)
    reg [31:0] max_diff;                      // Maximum difference
    reg [7:0] iter_count;                     // Iteration counter
    reg [7:0] neighbor_s, neighbor_t;         // Neighbor indices
    reg [7:0] pair_index;                     // For calculating pair index
    reg [2:0] n_reg;                          // Store n
    reg [2:0] start_s_reg, start_t_reg;       // Store start positions
    
    // Helper for pair indexing: pair(i,j) = i*8 + j (for 8x8 grid)
    wire [7:0] pair_idx_wire;
    assign pair_idx_wire = (i << 3) + j;  // i*8 + j
    
    // Degree calculation (combinational for each node)
    reg [7:0] deg_temp;
    integer idx;
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            expected_time <= 32'd0;
            done <= 1'b0;
            never_meet <= 1'b0;
            i <= 3'd0;
            j <= 3'd0;
            node_s <= 3'd0;
            node_t <= 3'd0;
            pair_idx <= 8'd0;
            temp_sum <= 32'd0;
            deg_i <= 8'd0;
            deg_j <= 8'd0;
            max_diff <= 32'd0;
            iter_count <= 8'd0;
            n_reg <= 3'd0;
            start_s_reg <= 3'd0;
            start_t_reg <= 3'd0;
            neighbor_s <= 8'd0;
            neighbor_t <= 8'd0;
            
            // Initialize adjacency matrix
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    adj_matrix[i][j] <= 1'b0;
                end
            end
            
            // Initialize E array
            for (i = 0; i < 64; i = i + 1) begin
                E[i] <= 32'd0;
                E_next[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    never_meet <= 1'b0;
                    i <= 3'd0;
                    j <= 3'd0;
                    iter_count <= 8'd0;
                    
                    if (start) begin
                        n_reg <= n[2:0];
                        start_s_reg <= start_s[2:0];
                        start_t_reg <= start_t[2:0];
                    end
                end
                
                LOAD_MATRIX: begin
                    // Load adjacency matrix from inputs
                    case (i)
                        3'd0: begin
                            for (j = 0; j < 8; j = j + 1) begin
                                adj_matrix[i][j] <= adj_0[j];
                            end
                        end
                        3'd1: begin
                            for (j = 0; j < 8; j = j + 1) begin
                                adj_matrix[i][j] <= adj_1[j];
                            end
                        end
                        3'd2: begin
                            for (j = 0; j < 8; j = j + 1) begin
                                adj_matrix[i][j] <= adj_2[j];
                            end
                        end
                        3'd3: begin
                            for (j = 0; j < 8; j = j + 1) begin
                                adj_matrix[i][j] <= adj_3[j];
                            end
                        end
                        3'd4: begin
                            for (j = 0; j < 8; j = j + 1) begin
                                adj_matrix[i][j] <= adj_4[j];
                            end
                        end
                        3'd5: begin
                            for (j = 0; j < 8; j = j + 1) begin
                                adj_matrix[i][j] <= adj_5[j];
                            end
                        end
                        3'd6: begin
                            for (j = 0; j < 8; j = j + 1) begin
                                adj_matrix[i][j] <= adj_6[j];
                            end
                        end
                        3'd7: begin
                            for (j = 0; j < 8; j = j + 1) begin
                                adj_matrix[i][j] <= adj_7[j];
                            end
                        end
                    endcase
                    i <= i + 3'd1;
                end
                
                INIT_VALUES: begin
                    // Initialize E and E_next arrays
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            if (i == j) begin
                                // Absorbing state: E = 0
                                E[(i<<3)+j] <= 32'd0;
                                E_next[(i<<3)+j] <= 32'd0;
                            end else begin
                                // Non-absorbing: initialize to 0
                                E[(i<<3)+j] <= 32'd0;
                                E_next[(i<<3)+j] <= 32'd0;
                            end
                        end
                    end
                end
                
                COMPUTE: begin
                    // Compute E_next from E
                    // For each pair (i,j) where i != j:
                    // E_next[i,j] = 1 + sum_{i' in N(i)} sum_{j' in N(j)} (1/deg(i))*(1/deg(j))*E[i',j']
                    
                    if (i != j && i < n_reg && j < n_reg) begin
                        // Calculate degree of i
                        deg_i <= 8'd0;
                        for (neighbor_s = 0; neighbor_s < n_reg; neighbor_s = neighbor_s + 1) begin
                            if (adj_matrix[i][neighbor_s]) begin
                                deg_i <= deg_i + 8'd1;
                            end
                        end
                        
                        // Calculate degree of j
                        deg_j <= 8'd0;
                        for (neighbor_t = 0; neighbor_t < n_reg; neighbor_t = neighbor_t + 1) begin
                            if (adj_matrix[j][neighbor_t]) begin
                                deg_j <= deg_j + 8'd1;
                            end
                        end
                        
                        // Calculate sum over neighbors
                        temp_sum <= 32'd0;
                        for (neighbor_s = 0; neighbor_s < n_reg; neighbor_s = neighbor_s + 1) begin
                            if (adj_matrix[i][neighbor_s]) begin
                                for (neighbor_t = 0; neighbor_t < n_reg; neighbor_t = neighbor_t + 1) begin
                                    if (adj_matrix[j][neighbor_t]) begin
                                        // Add E[neighbor_s, neighbor_t]
                                        if (neighbor_s != neighbor_t) begin
                                            temp_sum <= temp_sum + E[(neighbor_s<<3)+neighbor_t];
                                        end
                                    end
                                end
                            end
                        end
                        
                        // Multiply by (1/deg(i))*(1/deg(j))
                        // This is (1/(deg_i*deg_j))
                        // For Q16.16: multiply by 2^16 / (deg_i*deg_j)
                        if (deg_i != 8'd0 && deg_j != 8'd0) begin
                            // Q16.16 division: temp_sum * 2^16 / (deg_i * deg_j)
                            E_next[(i<<3)+j] <= (temp_sum * Q16_SCALE) / (deg_i * deg_j);
                        end else begin
                            // No neighbors - can't compute
                            E_next[(i<<3)+j] <= 32'h7FFFFFFF;  // Infinity
                        end
                        
                        // Add 1 (Q16.16: 0x00010000)
                        E_next[(i<<3)+j] <= E_next[(i<<3)+j] + 32'h00010000;
                    end
                    
                    // Increment counters
                    if (j == 3'd7) begin
                        j <= 3'd0;
                        if (i == 3'd7) begin
                            i <= 3'd0;
                        end else begin
                            i <= i + 3'd1;
                        end
                    end else begin
                        j <= j + 3'd1;
                    end
                end
                
                CHECK_CONVERGENCE: begin
                    // Compare E_next with E and find max difference
                    max_diff <= 32'd0;
                    
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            if (i != j) begin
                                // Calculate absolute difference
                                if (E_next[(i<<3)+j] > E[(i<<3)+j]) begin
                                    if (E_next[(i<<3)+j] - E[(i<<3)+j] > max_diff) begin
                                        max_diff <= E_next[(i<<3)+j] - E[(i<<3)+j];
                                    end
                                end else begin
                                    if (E[(i<<3)+j] - E_next[(i<<3)+j] > max_diff) begin
                                        max_diff <= E[(i<<3)+j] - E_next[(i<<3)+j];
                                    end
                                end
                            end
                        end
                    end
                    
                    // Copy E_next to E for next iteration
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            E[(i<<3)+j] <= E_next[(i<<3)+j];
                        end
                    end
                    
                    iter_count <= iter_count + 8'd1;
                end
                
                DONE_STATE: begin
                    // Set outputs
                    expected_time <= E[(start_s_reg<<3)+start_t_reg];
                    done <= 1'b1;
                    
                    // Check if never meet (infinity or max iterations reached)
                    if (iter_count >= MAX_ITER || 
                        E[(start_s_reg<<3)+start_t_reg] >= 32'h7FFFFFF0) begin
                        never_meet <= 1'b1;
                    end
                end
            endcase
        end
    end
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = LOAD_MATRIX;
                else next_state = IDLE;
            end
            
            LOAD_MATRIX: begin
                if (i == 3'd8) next_state = INIT_VALUES;
                else next_state = LOAD_MATRIX;
            end
            
            INIT_VALUES: begin
                next_state = COMPUTE;
            end
            
            COMPUTE: begin
                if (i == 3'd7 && j == 3'd7) begin
                    next_state = CHECK_CONVERGENCE;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            CHECK_CONVERGENCE: begin
                if (max_diff < THRESHOLD || iter_count >= MAX_ITER) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule