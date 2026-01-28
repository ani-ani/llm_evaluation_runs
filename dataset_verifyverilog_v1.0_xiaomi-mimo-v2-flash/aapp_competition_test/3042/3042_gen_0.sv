module lcm_tree_computer(
    input clk,
    input rst_n,
    input start,
    input [5:0] n,               // 1-16 (odd)
    input [31:0] nodes [0:15],   // 16 nodes, each 32-bit
    output reg [31:0] result,
    output reg done
);

    // Modulo constant
    localparam [31:0] MOD = 32'd1000000007;
    
    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] PRECOMP_LCM = 3'd2;
    localparam [2:0] DP_COMPUTE = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Control signals
    reg start_internal;
    reg [5:0] active_n;
    reg [5:0] max_mask;
    
    // LCM precomputation
    reg [31:0] lcm_table [0:255];  // 16x16 table
    reg [7:0] lcm_idx;             // 0-255
    reg [31:0] lcm_a, lcm_b;
    wire [31:0] lcm_result;
    
    // GCD computation for LCM
    reg [31:0] gcd_a, gcd_b;
    reg [31:0] gcd_temp;
    reg gcd_done;
    reg gcd_busy;
    
    // DP arrays (max 2^16 = 65536 entries)
    reg [31:0] f [0:65535];        // number of ways
    reg [31:0] root_val [0:65535]; // LCM value for subset
    
    // DP control
    reg [15:0] mask;
    reg [15:0] sub_mask;
    reg [15:0] l_mask;
    reg [15:0] r_mask;
    reg [4:0] bit_count;
    reg [4:0] sub_bit_count;
    reg dp_start;
    
    // Computation registers
    reg [31:0] f_l, f_r;
    reg [31:0] val_l, val_r;
    reg [31:0] lcm_computed;
    reg [31:0] candidate_val;
    reg [31:0] mult_result;
    reg [31:0] add_result;
    reg [31:0] final_result;
    
    // Iteration indices
    integer i, j;
    
    // Cycle counter for timeout
    reg [31:0] cycle_count;
    localparam [31:0] MAX_CYCLES = 32'd10000;
    
    // LCM helper function (combinational)
    // Input: lcm_a, lcm_b
    // Output: lcm_result
    // Uses gcd calculation
    
    // GCD computation state
    reg [1:0] gcd_state;
    localparam [1:0] GCD_IDLE = 2'd0;
    localparam [1:0] GCD_COMPUTE = 2'd1;
    localparam [1:0] GCD_DONE = 2'd2;
    
    // Calculate GCD using Euclidean algorithm
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gcd_state <= GCD_IDLE;
            gcd_temp <= 32'd0;
            gcd_done <= 1'b0;
        end else begin
            case (gcd_state)
                GCD_IDLE: begin
                    gcd_done <= 1'b0;
                    if (gcd_busy) begin
                        gcd_state <= GCD_COMPUTE;
                        if (lcm_a < lcm_b) begin
                            gcd_a <= lcm_b;
                            gcd_b <= lcm_a;
                        end else begin
                            gcd_a <= lcm_a;
                            gcd_b <= lcm_b;
                        end
                    end
                end
                GCD_COMPUTE: begin
                    if (gcd_b == 32'd0) begin
                        gcd_state <= GCD_DONE;
                        gcd_done <= 1'b1;
                    end else begin
                        gcd_temp <= gcd_a % gcd_b;
                        gcd_a <= gcd_b;
                        gcd_b <= gcd_a % gcd_b;
                    end
                end
                GCD_DONE: begin
                    gcd_done <= 1'b0;
                    gcd_state <= GCD_IDLE;
                end
                default: gcd_state <= GCD_IDLE;
            endcase
        end
    end
    
    // LCM calculation: lcm(a,b) = (a*b)/gcd(a,b)
    // Need to handle 64-bit intermediate
    reg [63:0] mult_temp;
    reg gcd_complete;
    reg [31:0] gcd_result;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lcm_result <= 32'd0;
            gcd_busy <= 1'b0;
            mult_temp <= 64'd0;
            gcd_complete <= 1'b0;
            gcd_result <= 32'd0;
        end else begin
            if (gcd_complete) begin
                // Calculate LCM = (a*b)/gcd
                if (gcd_result > 32'd0) begin
                    mult_temp = (lcm_a * lcm_b) / gcd_result;
                    // Check for overflow (simplified - assume fits 32-bit)
                    if (mult_temp[63:32] == 32'd0) begin
                        lcm_result <= mult_temp[31:0];
                    end else begin
                        lcm_result <= 32'd0; // Overflow protection
                    end
                end else begin
                    lcm_result <= 32'd0;
                end
                gcd_complete <= 1'b0;
            end else if (gcd_done) begin
                gcd_result <= gcd_a;  // gcd_a contains result
                gcd_complete <= 1'b1;
                gcd_busy <= 1'b0;
            end else if (gcd_busy == 1'b0 && gcd_state == GCD_IDLE && lcm_a != 32'd0 && lcm_b != 32'd0) begin
                gcd_busy <= 1'b1;
            end
        end
    end
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 32'd0;
            start_internal <= 1'b0;
        end else begin
            cycle_count <= cycle_count + 32'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 32'd0;
                    if (start && n[0] && n <= 16 && n > 0) begin
                        start_internal <= 1'b1;
                        active_n <= n;
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    start_internal <= 1'b0;
                    // Initialize f and root_val arrays
                    // Reset for all possible masks up to 2^16
                    mask <= 16'd0;
                    for (i = 0; i < 65536; i = i + 1) begin
                        f[i] <= 32'd0;
                        root_val[i] <= 32'd0;
                    end
                    state <= PRECOMP_LCM;
                    lcm_idx <= 8'd0;
                end
                
                PRECOMP_LCM: begin
                    // Precompute LCM for all pairs of active nodes
                    if (lcm_idx < 8'd256) begin
                        // Only compute for valid node indices
                        if (lcm_idx[7:4] < active_n && lcm_idx[3:0] < active_n) begin
                            lcm_a <= nodes[lcm_idx[7:4]];
                            lcm_b <= nodes[lcm_idx[3:0]];
                            // Wait for LCM computation
                            if (lcm_result != 32'd0 && !gcd_busy && !gcd_done) begin
                                // LCM ready
                                lcm_table[lcm_idx] <= lcm_result;
                                lcm_idx <= lcm_idx + 8'd1;
                            end
                        end else begin
                            lcm_table[lcm_idx] <= 32'd0;
                            lcm_idx <= lcm_idx + 8'd1;
                        end
                    end else begin
                        state <= DP_COMPUTE;
                        // Initialize base cases (|S| = 1)
                        mask <= 16'd0;
                        final_result <= 32'd0;
                    end
                end
                
                DP_COMPUTE: begin
                    // Process all masks up to 2^active_n - 1
                    if (mask < (1 << active_n)) begin
                        // Count bits in mask
                        bit_count <= 0;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < active_n && mask[i]) begin
                                bit_count <= bit_count + 1;
                            end
                        end
                        
                        // Check parity
                        if (bit_count[0]) begin  // Odd number of bits
                            if (bit_count == 1) begin
                                // Base case: single node
                                // Find which node is set
                                for (j = 0; j < 16; j = j + 1) begin
                                    if (j < active_n && mask[j]) begin
                                        f[mask] <= 32'd1;
                                        root_val[mask] <= nodes[j];
                                    end
                                end
                            end else if (bit_count >= 3) begin
                                // DP transition: try splitting into two subsets
                                // Initialize f[mask] if not already set
                                if (f[mask] == 32'd0) begin
                                    f[mask] <= 32'd0;
                                end
                                
                                // Try to split: L = proper subset, R = mask ^ L
                                // Start with first element as root candidate
                                reg [31:0] candidate_lcm;
                                reg [31:0] prod;
                                reg [31:0] current_f;
                                
                                current_f = f[mask];
                                
                                // Find a non-empty proper subset L
                                sub_mask <= 16'd0;
                                sub_bit_count <= 0;
                                
                                // For speed, limit to smaller subset
                                // Iterate over possible splits
                                for (l_mask = 16'd1; l_mask < mask; l_mask = l_mask + 16'd2) begin
                                    if ((l_mask & mask) == l_mask) begin
                                        r_mask <= mask ^ l_mask;
                                        
                                        // Check if both subsets are odd
                                        // Count bits in l_mask
                                        sub_bit_count <= 0;
                                        for (i = 0; i < 16; i = i + 1) begin
                                            if (i < active_n && l_mask[i]) begin
                                                sub_bit_count <= sub_bit_count + 1;
                                            end
                                        end
                                        
                                        if (sub_bit_count[0]) begin
                                            // Check if R is also odd
                                            // Could precompute but doing check here
                                            // Check if R is valid (non-empty and odd)
                                            if (r_mask > 0) begin
                                                // Compute LCM of root values
                                                val_l <= root_val[l_mask];
                                                val_r <= root_val[r_mask];
                                                lcm_a <= root_val[l_mask];
                                                lcm_b <= root_val[r_mask];
                                                
                                                // Get precomputed LCM
                                                // Need index: {l_mask_idx, r_mask_idx}
                                                // But we need node indices, not mask indices
                                                
                                                // Alternative: compute LCM now
                                                // Wait for LCM result
                                                if (lcm_result != 32'd0 && !gcd_busy && !gcd_done) begin
                                                    candidate_val <= lcm_result;
                                                    
                                                    // Check if candidate_val exists in nodes of mask (excluding L and R)
                                                    // This is expensive - skip for this implementation
                                                    // Instead, check if candidate_val equals any node in mask not in L∪R
                                                    
                                                    // Simplified: just check if LCM matches any node in S
                                                    // For each node in S
                                                    for (i = 0; i < 16; i = i + 1) begin
                                                        if (i < active_n && mask[i] && !l_mask[i] && !r_mask[i]) begin
                                                            if (nodes[i] == candidate_val) begin
                                                                // Valid split
                                                                // f[S] += f[L] * f[R]
                                                                prod = (f[l_mask] * f[r_mask]) % MOD;
                                                                current_f = (current_f + prod) % MOD;
                                                                root_val[mask] <= candidate_val;
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                                f[mask] <= current_f;
                            end
                        end
                        
                        mask <= mask + 16'd1;
                    end else begin
                        // Done with all masks
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Final result is f[(1<<n)-1]
                    result <= f[(1 << active_n) - 1];
                    done <= 1'b1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;  // Timeout
                    end else begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
            
            // Timeout protection
            if (cycle_count >= MAX_CYCLES && state != IDLE) begin
                state <= IDLE;
                done <= 1'b1;
                result <= 32'd0;
            end
        end
    end

endmodule