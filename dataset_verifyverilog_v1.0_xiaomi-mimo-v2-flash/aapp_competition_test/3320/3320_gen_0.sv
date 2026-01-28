module MagicalIslandTransport(
    input clk,
    input rst_n,
    input start,
    input [2:0] src,
    input [2:0] dst,
    input [3:0] edge_u,
    input [3:0] edge_v,
    input [7:0] edge_w,
    input config_valid,
    output reg [7:0] result,
    output reg done,
    output reg busy
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CONFIG = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] QUERY = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // State registers
    reg [2:0] state, next_state;
    
    // Distance matrix: 8x8 packed into 64 registers
    reg [7:0] dist [0:63];  // dist[i*8 + j] = distance from i to j
    
    // Loop counters
    reg [2:0] k_reg, i_reg, j_reg;
    reg [2:0] next_k, next_i, next_j;
    
    // Edge configuration counter
    reg [4:0] edge_count;  // 0-16 edges
    reg [4:0] config_limit;  // How many edges to configure
    
    // Query counter for multiple queries
    reg [3:0] query_count;
    
    // Temporary registers for computation
    reg [7:0] temp_dist;
    reg [7:0] or_result;
    reg [7:0] new_dist;
    
    // Cycle counter for safety
    reg [13:0] cycle_counter;  // Up to 16383 cycles
    localparam [13:0] MAX_COMPUTE_CYCLES = 14'd1000;
    
    // Edge configuration registers
    reg [7:0] u_idx, v_idx, weight;
    reg config_valid_d;
    
    // Finite State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            busy <= 1'b0;
            result <= 8'd0;
            k_reg <= 3'd0;
            i_reg <= 3'd0;
            j_reg <= 3'd0;
            edge_count <= 5'd0;
            query_count <= 4'd0;
            cycle_counter <= 14'd0;
            config_limit <= 5'd0;
            temp_dist <= 8'd0;
            or_result <= 8'd0;
            new_dist <= 8'd0;
            config_valid_d <= 1'b0;
            u_idx <= 8'd0;
            v_idx <= 8'd0;
            weight <= 8'd0;
            
            // Initialize distance matrix
            // dist[0] through dist[63] to infinity (8'd255)
            dist[0] <= 8'd255; dist[1] <= 8'd255; dist[2] <= 8'd255; dist[3] <= 8'd255;
            dist[4] <= 8'd255; dist[5] <= 8'd255; dist[6] <= 8'd255; dist[7] <= 8'd255;
            dist[8] <= 8'd255; dist[9] <= 8'd255; dist[10] <= 8'd255; dist[11] <= 8'd255;
            dist[12] <= 8'd255; dist[13] <= 8'd255; dist[14] <= 8'd255; dist[15] <= 8'd255;
            dist[16] <= 8'd255; dist[17] <= 8'd255; dist[18] <= 8'd255; dist[19] <= 8'd255;
            dist[20] <= 8'd255; dist[21] <= 8'd255; dist[22] <= 8'd255; dist[23] <= 8'd255;
            dist[24] <= 8'd255; dist[25] <= 8'd255; dist[26] <= 8'd255; dist[27] <= 8'd255;
            dist[28] <= 8'd255; dist[29] <= 8'd255; dist[30] <= 8'd255; dist[31] <= 8'd255;
            dist[32] <= 8'd255; dist[33] <= 8'd255; dist[34] <= 8'd255; dist[35] <= 8'd255;
            dist[36] <= 8'd255; dist[37] <= 8'd255; dist[38] <= 8'd255; dist[39] <= 8'd255;
            dist[40] <= 8'd255; dist[41] <= 8'd255; dist[42] <= 8'd255; dist[43] <= 8'd255;
            dist[44] <= 8'd255; dist[45] <= 8'd255; dist[46] <= 8'd255; dist[47] <= 8'd255;
            dist[48] <= 8'd255; dist[49] <= 8'd255; dist[50] <= 8'd255; dist[51] <= 8'd255;
            dist[52] <= 8'd255; dist[53] <= 8'd255; dist[54] <= 8'd255; dist[55] <= 8'd255;
            dist[56] <= 8'd255; dist[57] <= 8'd255; dist[58] <= 8'd255; dist[59] <= 8'd255;
            dist[60] <= 8'd255; dist[61] <= 8'd255; dist[62] <= 8'd255; dist[63] <= 8'd255;
        end else begin
            state <= next_state;
            k_reg <= next_k;
            i_reg <= next_i;
            j_reg <= next_j;
            config_valid_d <= config_valid;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    cycle_counter <= 14'd0;
                    query_count <= 4'd0;
                    edge_count <= 5'd0;
                    
                    if (start) begin
                        busy <= 1'b1;
                        next_state <= CONFIG;
                        // Initialize self-distances to 0
                        dist[0] <= 8'd0; dist[9] <= 8'd0; dist[18] <= 8'd0; dist[27] <= 8'd0;
                        dist[36] <= 8'd0; dist[45] <= 8'd0; dist[54] <= 8'd0; dist[63] <= 8'd0;
                    end
                end
                
                CONFIG: begin
                    if (config_valid && (edge_count < 5'd16)) begin
                        u_idx <= {5'd0, edge_u[2:0]};  // Store city index (0-7)
                        v_idx <= {5'd0, edge_v[2:0]};
                        weight <= edge_w;
                        edge_count <= edge_count + 5'd1;
                        
                        // Update distance matrix for this edge
                        // D[u][v] = min(D[u][v], w)
                        // D[v][u] = min(D[v][u], w)
                        if (edge_w < dist[{edge_u[2:0], edge_v[2:0]}]) begin
                            dist[{edge_u[2:0], edge_v[2:0]}] <= edge_w;
                        end
                        if (edge_w < dist[{edge_v[2:0], edge_u[2:0]}]) begin
                            dist[{edge_v[2:0], edge_u[2:0]}] <= edge_w;
                        end
                    end
                    
                    if (!config_valid && (edge_count > 5'd0)) begin
                        next_state <= COMPUTE;
                        next_k <= 3'd0;
                        next_i <= 3'd0;
                        next_j <= 3'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_counter <= cycle_counter + 14'd1;
                    
                    // Floyd-Warshall: D[i][j] = min(D[i][j], D[i][k] | D[k][j])
                    if (k_reg < 3'd8) begin
                        if (i_reg < 3'd8) begin
                            if (j_reg < 3'd8) begin
                                // Compute OR and min
                                or_result <= dist[{i_reg, k_reg}] | dist[{k_reg, j_reg}];
                                
                                // Compare and update
                                temp_dist <= dist[{i_reg, j_reg}];
                                
                                // Next j
                                if (dist[{i_reg, k_reg}] | dist[{k_reg, j_reg}] < dist[{i_reg, j_reg}]) begin
                                    dist[{i_reg, j_reg}] <= dist[{i_reg, k_reg}] | dist[{k_reg, j_reg}];
                                end
                                next_j <= j_reg + 3'd1;
                            end else begin
                                // Next i, reset j
                                next_i <= i_reg + 3'd1;
                                next_j <= 3'd0;
                            end
                        end else begin
                            // Next k, reset i and j
                            next_k <= k_reg + 3'd1;
                            next_i <= 3'd0;
                            next_j <= 3'd0;
                        end
                    end else begin
                        // Computation complete
                        next_state <= QUERY;
                    end
                    
                    // Safety timeout
                    if (cycle_counter >= MAX_COMPUTE_CYCLES) begin
                        next_state <= QUERY;
                    end
                end
                
                QUERY: begin
                    // Output result for src/dst
                    result <= dist[{src, dst}];
                    done <= 1'b1;
                    query_count <= query_count + 4'd1;
                    
                    // Stay in QUERY for multiple queries
                    // Exit after reasonable number or if stopped
                    if (query_count >= 4'd10) begin
                        next_state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

    // Continuous assignment for next_state logic (already handled in always block)
    always @(*) begin
        next_state = state;
        next_k = k_reg;
        next_i = i_reg;
        next_j = j_reg;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CONFIG;
                end
            end
            
            CONFIG: begin
                if (!config_valid && (edge_count > 5'd0)) begin
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                // Logic handled in sequential block
            end
            
            QUERY: begin
                // Stay in query until timeout or stop
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule