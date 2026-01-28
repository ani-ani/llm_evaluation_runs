module shipment_partition (
    input clk,
    input rst_n,
    input start,
    input [255:0] dist_matrix,
    input [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] SETUP        = 4'd1;
    localparam [3:0] PRECOMP_INIT = 4'd2;
    localparam [3:0] PRECOMP_LOOP = 4'd3;
    localparam [3:0] DP_INIT      = 4'd4;
    localparam [3:0] DP_LOOP      = 4'd5;
    localparam [3:0] DP_COMPUTE   = 4'd6;
    localparam [3:0] COMPLEMENT   = 4'd7;
    localparam [3:0] COMBINE      = 4'd8;
    localparam [3:0] FINISH       = 4'd9;

    // Internal registers
    reg [3:0] state, next_state;
    reg [3:0] max_n;              // Stores actual n used
    reg [9:0] max_mask;           // 2^n - 1
    reg [9:0] mask;               // Current subset mask
    reg [9:0] prev_mask;          // For DP
    reg [15:0] dp [0:1023];       // DP table for n <= 10
    reg [11:0] d_matrix [0:3][0:3]; // Distance matrix (4x4 for n<=4)
    reg [11:0] subset_max [0:1023]; // Precomputed D(S) values
    reg [15:0] current_sum;
    reg [15:0] best_sum;
    reg [11:0] max_dist;
    reg [3:0] i, j;               // Loop counters
    reg [9:0] temp_mask;
    reg [15:0] candidate;
    
    // For DP: iterate over masks
    reg [9:0] dp_mask;
    reg [3:0] dp_bit;
    reg [9:0] dp_prev;
    reg [15:0] dp_candidate;
    reg [15:0] dp_min;
    
    // Complement computation
    reg [9:0] comp_mask;
    reg [11:0] comp_max;
    
    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            mask <= 10'd0;
            prev_mask <= 10'd0;
            current_sum <= 16'd0;
            best_sum <= 16'd0;
            max_dist <= 12'd0;
            i <= 4'd0;
            j <= 4'd0;
            temp_mask <= 10'd0;
            candidate <= 16'd0;
            dp_mask <= 10'd0;
            dp_bit <= 4'd0;
            dp_prev <= 10'd0;
            dp_candidate <= 16'd0;
            dp_min <= 16'd0;
            comp_mask <= 10'd0;
            comp_max <= 12'd0;
            max_n <= 4'd0;
            max_mask <= 10'd0;
            for (k = 0; k < 1024; k = k + 1) begin
                dp[k] <= 16'd0;
                subset_max[k] <= 12'd0;
            end
            for (k = 0; k < 4; k = k + 1) begin
                d_matrix[k][0] <= 12'd0;
                d_matrix[k][1] <= 12'd0;
                d_matrix[k][2] <= 12'd0;
                d_matrix[k][3] <= 12'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'd0;
                    if (start && n > 4'd0 && n <= 4'd16) begin
                        max_n <= n;
                        max_mask <= (1 << n) - 1;  // 2^n - 1
                    end
                end
                
                SETUP: begin
                    // Unpack distance matrix for n <= 4
                    // dist_matrix is 256 bits, packing 4x4=16 12-bit values
                    // Matrix stored row-wise: [0][0], [0][1], [0][2], [0][3], [1][0]...
                    if (i < max_n && j < max_n) begin
                        d_matrix[i][j] <= dist_matrix[(i*4 + j)*12 +: 12];
                        if (j < max_n - 1) begin
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end
                    if (i >= max_n && j >= max_n) begin
                        i <= 4'd0;
                        j <= 4'd0;
                    end
                end
                
                PRECOMP_INIT: begin
                    // Initialize first non-empty subset
                    mask <= 4'd1;
                    subset_max[1] <= d_matrix[0][1];  // Assuming subset {0,1}
                    i <= 4'd1;
                    j <= 4'd0;
                end
                
                PRECOMP_LOOP: begin
                    // For current mask, compute max distance
                    if (i < max_n) begin
                        if (mask[i] && i > 4'd0) begin
                            // Check pair (i,j) where j < i and mask[j]
                            if (j < i) begin
                                if (mask[j]) begin
                                    // Update max for this subset
                                    if (d_matrix[i][j] > max_dist) begin
                                        max_dist <= d_matrix[i][j];
                                    end
                                end
                                j <= j + 4'd1;
                            end else begin
                                j <= 4'd0;
                                i <= i + 4'd1;
                            end
                        end else begin
                            i <= i + 4'd1;
                        end
                    end else begin
                        // Store result and move to next mask
                        subset_max[mask] <= max_dist;
                        if (mask < max_mask) begin
                            mask <= mask + 4'd1;
                            max_dist <= 12'd0;
                            i <= 4'd1;
                            j <= 4'd0;
                        end
                    end
                end
                
                DP_INIT: begin
                    // Initialize DP: empty set has cost 0
                    dp[0] <= 16'd0;
                    dp_mask <= 4'd1;
                    dp_min <= 16'hFFFF;
                    dp_bit <= 4'd0;
                end
                
                DP_LOOP: begin
                    // For each subset, try removing one element
                    if (dp_bit < max_n) begin
                        if (dp_mask[dp_bit]) begin
                            dp_prev <= dp_mask ^ (1 << dp_bit);
                            dp_bit <= dp_bit + 4'd1;
                        end else begin
                            dp_bit <= dp_bit + 4'd1;
                        end
                    end else begin
                        // Store minimum
                        if (dp_min != 16'hFFFF) begin
                            dp[dp_mask] <= dp_min;
                        end
                        if (dp_mask < max_mask) begin
                            dp_mask <= dp_mask + 4'd1;
                            dp_bit <= 4'd0;
                            dp_min <= 16'hFFFF;
                        end
                    end
                end
                
                DP_COMPUTE: begin
                    // Compute candidate = dp[dp_prev] + subset_max[dp_prev]
                    dp_candidate <= dp[dp_prev] + {4'd0, subset_max[dp_prev]};
                    // Update min
                    if (dp_candidate < dp_min) begin
                        dp_min <= dp_candidate;
                    end
                end
                
                COMPLEMENT: begin
                    // Compute complement mask
                    comp_mask <= (~mask) & max_mask;
                    // Get complement max
                    comp_max <= subset_max[comp_mask];
                end
                
                COMBINE: begin
                    // candidate = dp[comp_mask] + comp_max + subset_max[mask]
                    candidate <= dp[comp_mask] + {4'd0, comp_max} + {4'd0, subset_max[mask]};
                    // Update best
                    if (mask < max_mask && candidate < best_sum) begin
                        best_sum <= candidate;
                    end
                    // Move to next mask
                    if (mask < max_mask) begin
                        mask <= mask + 4'd1;
                        i <= 4'd0;
                        j <= 4'd0;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= best_sum;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && n > 4'd0 && n <= 4'd16) begin
                    next_state = SETUP;
                end else begin
                    next_state = IDLE;
                end
            end
            
            SETUP: begin
                if (i >= max_n && j >= max_n) begin
                    next_state = PRECOMP_INIT;
                end else begin
                    next_state = SETUP;
                end
            end
            
            PRECOMP_INIT: begin
                next_state = PRECOMP_LOOP;
            end
            
            PRECOMP_LOOP: begin
                if (mask >= max_mask && i >= max_n) begin
                    // Skip empty set (mask=0) and complete
                    next_state = DP_INIT;
                end else begin
                    next_state = PRECOMP_LOOP;
                end
            end
            
            DP_INIT: begin
                next_state = DP_LOOP;
            end
            
            DP_LOOP: begin
                if (dp_bit >= max_n) begin
                    next_state = DP_COMPUTE;
                end else if (dp_mask[dp_bit]) begin
                    next_state = DP_COMPUTE;
                end else begin
                    next_state = DP_LOOP;
                end
            end
            
            DP_COMPUTE: begin
                // Go back to loop to check next bit
                next_state = DP_LOOP;
            end
            
            COMPLEMENT: begin
                next_state = COMBINE;
            end
            
            COMBINE: begin
                if (mask >= max_mask) begin
                    next_state = FINISH;
                end else begin
                    next_state = COMPLEMENT;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule