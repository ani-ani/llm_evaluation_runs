module ShortestPaths (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] node_count,
    input wire [23:0] edges [0:15],
    input wire [15:0] edge_valid,
    output reg [15:0] result [0:7],
    output reg done
);

    // Constants
    localparam [15:0] INF = 16'd65535;
    localparam [31:0] MOD = 32'd1000000007;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] INIT = 3'd2;
    localparam [2:0] FW_K = 3'd3;
    localparam [2:0] SUM = 3'd4;
    localparam [2:0] FINISH = 3'd5;
    
    // Registers
    reg [2:0] state, next_state;
    reg [3:0] i, j, k;
    reg [15:0] dist [0:7][0:7];
    reg [15:0] sum_acc [0:7];
    reg [7:0] cycle_count;
    reg start_d;
    
    // Wires for combinational logic
    wire [3:0] src, dst;
    wire [7:0] len;
    wire [15:0] dist_ik, dist_kj, dist_ij;
    wire [15:0] new_dist;
    wire [15:0] current_dist;
    wire [31:0] sum_temp;
    wire [15:0] sum_mod;
    wire [3:0] N;
    
    // Extract edge fields
    assign src = edges[k][23:20];
    assign dst = edges[k][19:16];
    assign len = edges[k][7:0];
    
    // Get distances for Floyd-Warshall
    assign dist_ik = dist[i][k];
    assign dist_kj = dist[k][j];
    assign dist_ij = dist[i][j];
    
    // Calculate new distance with overflow protection
    wire [16:0] sum_temp_17 = {1'b0, dist_ik} + {1'b0, dist_kj};
    wire [15:0] sum_temp_16 = sum_temp_17[15:0];
    assign new_dist = (sum_temp_16 < dist_ij) ? sum_temp_16 : dist_ij;
    
    // Sum calculation
    assign sum_temp = {16'd0, sum_acc[i]} + {16'd0, dist[i][j]};
    assign sum_mod = sum_temp[15:0];
    
    assign N = node_count;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            start_d <= 1'b0;
        end else begin
            start_d <= start;
            state <= next_state;
        end
    end
    
    // Main logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            
            // Reset result array
            for (integer r = 0; r < 8; r = r + 1) begin
                result[r] <= 16'd0;
            end
            
            // Reset sum accumulator
            for (integer s = 0; s < 8; s = s + 1) begin
                sum_acc[s] <= 16'd0;
            end
            
            // Reset distance matrix
            for (integer row = 0; row < 8; row = row + 1) begin
                for (integer col = 0; col < 8; col = col + 1) begin
                    dist[row][col] <= INF;
                end
            end
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start || start_d) begin
                        i <= 4'd0;
                        j <= 4'd0;
                        k <= 4'd0;
                    end
                end
                
                LOAD: begin
                    // Initialize diagonal and load edges
                    if (i < N) begin
                        dist[i][i] <= 16'd0;
                        i <= i + 4'd1;
                    end else if (k < 16) begin
                        if (edge_valid[k]) begin
                            if (src < N && dst < N) begin
                                dist[src][dst] <= {8'd0, len};
                                dist[dst][src] <= {8'd0, len};
                            end
                        end
                        k <= k + 4'd1;
                    end
                end
                
                INIT: begin
                    // Reset state variables for Floyd-Warshall
                    k <= 4'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                end
                
                FW_K: begin
                    if (k < N) begin
                        if (i < N) begin
                            if (j < N) begin
                                // Perform Floyd-Warshall update
                                if (dist_ik != INF && dist_kj != INF) begin
                                    if (new_dist < dist[i][j]) begin
                                        dist[i][j] <= new_dist;
                                    end
                                end
                                j <= j + 4'd1;
                            end else begin
                                j <= 4'd0;
                                i <= i + 4'd1;
                            end
                        end else begin
                            i <= 4'd0;
                            k <= k + 4'd1;
                        end
                        cycle_count <= cycle_count + 8'd1;
                    end else begin
                        // Done with Floyd-Warshall
                        i <= 4'd0;
                        j <= 4'd0;
                    end
                end
                
                SUM: begin
                    if (i < N) begin
                        if (j < N) begin
                            if (dist[i][j] != INF) begin
                                sum_acc[i] <= sum_mod;
                            end
                            j <= j + 4'd1;
                        end else begin
                            // Store result and reset for next node
                            result[i] <= sum_acc[i];
                            sum_acc[i] <= 16'd0;
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                        cycle_count <= cycle_count + 8'd1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    i <= 4'd0;
                    j <= 4'd0;
                    k <= 4'd0;
                    cycle_count <= 8'd0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start || start_d) begin
                    next_state = LOAD;
                end
            end
            
            LOAD: begin
                if (i >= N && k >= 16) begin
                    next_state = INIT;
                end
            end
            
            INIT: begin
                next_state = FW_K;
            end
            
            FW_K: begin
                if (k >= N) begin
                    next_state = SUM;
                end
            end
            
            SUM: begin
                if (i >= N) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule