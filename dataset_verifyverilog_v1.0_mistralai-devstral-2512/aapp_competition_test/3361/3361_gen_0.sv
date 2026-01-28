module shipment_partition(
    input clk,
    input rst_n,
    input start,
    input [255:0] dist_matrix,
    input [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Distance matrix storage (4x4 for n<=4, but we'll handle up to 16)
    reg [11:0] dist [0:15][0:15];
    integer i, j, k;

    // DP table: 2^10 entries for n<=10, but we'll use 2^16 for n<=16
    reg [15:0] dp [0:65535];
    reg [11:0] subset_max [0:65535];

    // Current mask and temporary variables
    reg [15:0] current_mask;
    reg [15:0] min_sum;
    reg [15:0] temp_sum;
    reg [11:0] max_dist_A;
    reg [11:0] max_dist_B;

    // Initialize distance matrix from packed input
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_mask <= 16'd0;
            min_sum <= 16'd65535;
            
            // Initialize DP table
            for (i = 0; i < 65536; i = i + 1) begin
                dp[i] <= 16'd65535;
                subset_max[i] <= 12'd0;
            end
            
            // Initialize distance matrix
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    dist[i][j] <= 12'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        
                        // Unpack distance matrix (for n<=4, 4x4=16 distances)
                        for (i = 0; i < 4; i = i + 1) begin
                            for (j = 0; j < 4; j = j + 1) begin
                                dist[i][j] <= dist_matrix[(i*4+j)*12 +: 12];
                            end
                        end
                        
                        // Initialize DP table
                        dp[0] <= 16'd0;
                        current_mask <= 16'd1;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Precompute subset_max for all masks
                    if (current_mask == 16'd0) begin
                        // Compute subset_max for all masks
                        for (i = 1; i < (1 << n); i = i + 1) begin
                            max_dist_A <= 12'd0;
                            for (j = 0; j < n; j = j + 1) begin
                                if (i[j]) begin
                                    for (k = 0; k < n; k = k + 1) begin
                                        if (i[k] && dist[j][k] > max_dist_A) begin
                                            max_dist_A <= dist[j][k];
                                        end
                                    end
                                end
                            end
                            subset_max[i] <= max_dist_A;
                        end
                        current_mask <= 16'd1;
                    end
                    
                    // Compute DP table
                    else if (current_mask < (1 << n)) begin
                        max_dist_A <= subset_max[current_mask];
                        max_dist_B <= subset_max[((1 << n) - 1) & ~current_mask];
                        temp_sum <= max_dist_A + max_dist_B;
                        
                        if (temp_sum < min_sum) begin
                            min_sum <= temp_sum;
                        end
                        
                        current_mask <= current_mask + 16'd1;
                        
                        if (current_mask >= (1 << n)) begin
                            state <= FINISH;
                        end
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= min_sum;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule