module min_weight_perfect_matching(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_nodes,
    input wire edge_valid,
    input wire [3:0] edge_u,
    input wire [3:0] edge_v,
    input wire [15:0] edge_weight,
    output reg [23:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] STORE_EDGES = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2048;

    // Edge storage (max 32 edges)
    reg [3:0] edge_list_u [0:31];
    reg [3:0] edge_list_v [0:31];
    reg [15:0] edge_list_weight [0:31];
    reg [4:0] edge_count;

    // DP table (65536 entries for 16 nodes)
    reg [23:0] dp [0:65535];
    
    // Current mask and iteration variables
    reg [15:0] current_mask;
    reg [3:0] i, j;
    reg [23:0] temp_weight;
    reg found_edge;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            edge_count <= 5'd0;
            
            // Initialize edge storage
            integer k;
            for (k = 0; k < 32; k = k + 1) begin
                edge_list_u[k] <= 4'd0;
                edge_list_v[k] <= 4'd0;
                edge_list_weight[k] <= 16'd0;
            end
            
            // Initialize DP table
            for (k = 0; k < 65536; k = k + 1) begin
                dp[k] <= 24'd0;
            end
            
            current_mask <= 16'd0;
            i <= 4'd0;
            j <= 4'd0;
            temp_weight <= 24'd0;
            found_edge <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= STORE_EDGES;
                    end
                end
                
                STORE_EDGES: begin
                    if (edge_valid && edge_count < 5'd32) begin
                        edge_list_u[edge_count] <= edge_u;
                        edge_list_v[edge_count] <= edge_v;
                        edge_list_weight[edge_count] <= edge_weight;
                        edge_count <= edge_count + 5'd1;
                    end
                    
                    if (!edge_valid && start) begin
                        state <= COMPUTE;
                        current_mask <= 16'd0;
                        i <= 4'd0;
                        j <= 4'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Base case: empty set
                    if (current_mask == 16'd0) begin
                        dp[0] <= 24'd0;
                        current_mask <= current_mask + 16'd1;
                    end
                    
                    // Iterate through all masks
                    else if (current_mask < (1 << num_nodes)) begin
                        // Find lowest set bit
                        i <= 4'd0;
                        while (i < 4'd16 && !(current_mask[i])) begin
                            i <= i + 4'd1;
                        end
                        
                        // Try to match with other bits
                        if (i < 4'd16) begin
                            j <= 4'd0;
                            temp_weight <= 24'd0;
                            found_edge <= 1'b0;
                            
                            // Search for edges from i to j
                            integer k;
                            for (k = 0; k < edge_count; k = k + 1) begin
                                if ((edge_list_u[k] == i && edge_list_v[k] == j && current_mask[j]) ||
                                    (edge_list_u[k] == j && edge_list_v[k] == i && current_mask[j])) begin
                                    found_edge <= 1'b1;
                                    temp_weight <= dp[current_mask - (1 << i) - (1 << j)] + edge_list_weight[k];
                                    
                                    // Update DP if better
                                    if (dp[current_mask] == 24'd0 || temp_weight < dp[current_mask]) begin
                                        dp[current_mask] <= temp_weight;
                                    end
                                end
                            end
                            
                            // Move to next j
                            j <= j + 4'd1;
                            if (j >= 4'd16) begin
                                current_mask <= current_mask + 16'd1;
                            end
                        end else begin
                            current_mask <= current_mask + 16'd1;
                        end
                    end
                    
                    // Check if computation is complete
                    if (current_mask >= (1 << num_nodes)) begin
                        state <= FINISH;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Check if perfect matching exists
                    if (num_nodes % 2 == 1 || dp[(1 << num_nodes) - 1] == 24'd0) begin
                        result <= 24'hFFFFFF;
                    end else begin
                        result <= dp[(1 << num_nodes) - 1];
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule