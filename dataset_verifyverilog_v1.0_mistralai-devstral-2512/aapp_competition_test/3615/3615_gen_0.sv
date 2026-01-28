module TowerCoverage(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    input wire signed [15:0] x [0:15],
    input wire signed [15:0] y [0:15],
    output reg [5:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] BUILD_ADJ = 3'd1;
    localparam [2:0] FIND_COMP = 3'd2;
    localparam [2:0] COMPUTE_MAX = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Adjacency matrix (16x16)
    reg [15:0] adj [0:15];
    reg [3:0] comp_id [0:15];
    reg [4:0] comp_size [0:15];
    reg [3:0] num_components;

    // BFS variables
    reg [3:0] queue [0:15];
    reg [3:0] q_head, q_tail;
    reg [15:0] visited;

    // Distance computation variables
    reg signed [15:0] dx, dy;
    reg [31:0] dx_sq, dy_sq, dist_sq;
    localparam [31:0] THRESHOLD_SQ = 32'd262144; // (512)^2 = 262144
    localparam [31:0] CONNECT_THRESHOLD_SQ = 32'd1048576; // (1024)^2 = 1048576

    // Computation variables
    reg [5:0] max_result;
    reg [3:0] i, j, k;
    reg [3:0] comp_i, comp_j;
    reg [4:0] size_i, size_j;
    reg [5:0] candidate;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 6'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Reset all internal registers
            for (i = 0; i < 16; i = i + 1) begin
                adj[i] <= 16'd0;
                comp_id[i] <= 4'd0;
                comp_size[i] <= 5'd0;
            end
            num_components <= 4'd0;
            q_head <= 4'd0;
            q_tail <= 4'd0;
            visited <= 16'd0;
            max_result <= 6'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= BUILD_ADJ;
                    end
                end

                BUILD_ADJ: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Build adjacency matrix
                    if (i < n) begin
                        if (j < n) begin
                            // Compute distance squared
                            dx <= x[i] - x[j];
                            dy <= y[i] - y[j];
                            dx_sq <= $signed(dx) * $signed(dx);
                            dy_sq <= $signed(dy) * $signed(dy);
                            dist_sq <= dx_sq + dy_sq;
                            
                            // Check if distance <= 1.0 (256 in Q8.8)
                            if (dist_sq <= THRESHOLD_SQ) begin
                                adj[i][j] <= 1'b1;
                            end else begin
                                adj[i][j] <= 1'b0;
                            end
                            
                            j <= j + 1'b1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 1'b1;
                        end
                    end else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        state <= FIND_COMP;
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                    end
                end

                FIND_COMP: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // BFS to find connected components
                    if (visited != 16'hFFFF) begin
                        // Find next unvisited node
                        if (k < 16 && visited[k]) begin
                            k <= k + 1'b1;
                        end else if (k < 16) begin
                            // Start BFS from node k
                            visited[k] <= 1'b1;
                            comp_id[k] <= num_components;
                            queue[q_tail] <= k;
                            q_tail <= q_tail + 1'b1;
                            comp_size[num_components] <= 5'd1;
                            k <= k + 1'b1;
                        end else if (q_head < q_tail) begin
                            // Process queue
                            i <= queue[q_head];
                            q_head <= q_head + 1'b1;
                            
                            for (j = 0; j < 16; j = j + 1) begin
                                if (adj[i][j] && !visited[j]) begin
                                    visited[j] <= 1'b1;
                                    comp_id[j] <= num_components;
                                    queue[q_tail] <= j;
                                    q_tail <= q_tail + 1'b1;
                                    comp_size[num_components] <= comp_size[num_components] + 5'd1;
                                end
                            end
                        end else begin
                            // Component complete
                            num_components <= num_components + 1'b1;
                            q_head <= 4'd0;
                            q_tail <= 4'd0;
                        end
                    end else begin
                        // All components found
                        k <= 4'd0;
                        i <= 4'd0;
                        j <= 4'd0;
                        state <= COMPUTE_MAX;
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                    end
                end

                COMPUTE_MAX: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute maximum result
                    if (num_components <= 1) begin
                        max_result <= n + 6'd1;
                        state <= DONE_STATE;
                    end else if (i < 16) begin
                        if (j < 16) begin
                            // Check if i and j are in different components
                            comp_i <= comp_id[i];
                            comp_j <= comp_id[j];
                            
                            if (comp_i != comp_j) begin
                                // Compute distance squared between i and j
                                dx <= x[i] - x[j];
                                dy <= y[i] - y[j];
                                dx_sq <= $signed(dx) * $signed(dx);
                                dy_sq <= $signed(dy) * $signed(dy);
                                dist_sq <= dx_sq + dy_sq;
                                
                                // Check if distance <= 2.0 (1024 in Q8.8)
                                if (dist_sq <= CONNECT_THRESHOLD_SQ) begin
                                    size_i <= comp_size[comp_i];
                                    size_j <= comp_size[comp_j];
                                    candidate <= size_i + size_j + 6'd1;
                                    
                                    if (candidate > max_result) begin
                                        max_result <= candidate;
                                    end
                                end
                            end
                            
                            j <= j + 1'b1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 1'b1;
                        end
                    end else begin
                        // Check if max_result is greater than n+1
                        if (max_result > (n + 6'd1)) begin
                            result <= max_result;
                        end else begin
                            result <= n + 6'd1;
                        end
                        state <= DONE_STATE;
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule