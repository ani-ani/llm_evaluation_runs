module count_valid_wirings (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [2:0] m,
    input [15:0] obs_switch [0:7],
    input [15:0] obs_light [0:7],
    output reg [23:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE     = 4'd0;
    localparam [3:0] SETUP    = 4'd1;
    localparam [3:0] DP_START = 4'd2;
    localparam [3:0] DP_LOOP  = 4'd3;
    localparam [3:0] CHECK_LIGHT = 4'd4;
    localparam [3:0] VALID    = 4'd5;
    localparam [3:0] ADD_RES  = 4'd6;
    localparam [3:0] NEXT_SWITCH = 4'd7;
    localparam [3:0] NEXT_MASK = 4'd8;
    localparam [3:0] FINISH   = 4'd9;

    reg [3:0] state, next_state;
    
    // DP parameters
    localparam [23:0] MODULO = 24'd1000003;
    
    // Switch index (0-15)
    reg [3:0] switch_idx;
    reg [3:0] switch_idx_next;
    
    // Light index for current switch (0-15)
    reg [3:0] light_idx;
    reg [3:0] light_idx_next;
    
    // Bitmask for used lights (16 bits max)
    reg [15:0] used_mask;
    reg [15:0] used_mask_next;
    
    // DP table: dp[switch][mask] = count
    // Max: 16 switches * 2^16 masks = 16 * 65536 = 1,048,576 entries
    // Too large for FPGA BRAM, use on-the-fly computation
    // Instead: use iterative approach, compute for each switch
    // Keep only current and previous switch results
    // dp_prev[mask] = count for previous switch
    // dp_curr[mask] = count for current switch
    reg [23:0] dp_prev [0:65535];  // This is too large!
    reg [23:0] dp_curr [0:65535];  // 64KB each = 128KB total
    
    // Alternative: Use recursion with stack or iterative with bit iteration
    // Better: Use DP with sparse masks (only relevant masks)
    // For n<=16, we can iterate over all 2^n masks
    // But 2^16 = 65536 is manageable
    // 65536 * 24 bits = 1.5M bits per table = ~2 KB
    // Actually 65536 * 24 = 1,572,864 bits = ~196 KB per table
    // 196KB * 2 = 392KB - this might be too large for some FPGAs
    
    // Let's optimize: use single table and iterate
    // Or use parameter-based sizing
    
    // Simpler approach for n<=16:
    // Use dp[2^16] but only allocate up to n bits
    // Actually, let's use a different approach:
    // Iterative DP: for each switch, build dp array
    // But we can compute on-the-fly without storing full table
    // by iterating over valid permutations using recursion/iterative
    
    // Let's use a more compact approach:
    // Store dp for current switch index only
    // dp[mask] = number of ways to assign switches 0..switch_idx
    
    // For n<=16, 2^16 = 65536 states
    // Each state is 24 bits = 196KB - acceptable for most FPGAs
    reg [23:0] dp [0:65535];  // 196KB BRAM
    reg [15:0] mask;
    reg [15:0] mask_next;
    reg [15:0] light_bit;
    reg [15:0] light_bit_next;
    
    // Temporary storage for consistency check
    reg [15:0] switch_bits;
    reg [15:0] light_bits;
    reg all_consistent;
    reg all_consistent_next;
    
    // Loop counters
    reg [4:0] obs_idx;
    reg [4:0] obs_idx_next;
    
    // For modulo addition
    reg [47:0] temp_sum;  // Double width for addition
    
    // Cycle counter for timeout protection
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd5000;  // Allow 5000 cycles
    
    // Array iteration
    integer i;
    integer k;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            switch_idx <= 4'd0;
            light_idx <= 4'd0;
            used_mask <= 16'd0;
            mask <= 16'd0;
            light_bit <= 16'd0;
            obs_idx <= 5'd0;
            all_consistent <= 1'b0;
            cycle_count <= 16'd0;
            switch_bits <= 16'd0;
            light_bits <= 16'd0;
            temp_sum <= 48'd0;
            switch_idx_next <= 4'd0;
            light_idx_next <= 4'd0;
            used_mask_next <= 16'd0;
            mask_next <= 16'd0;
            light_bit_next <= 16'd0;
            obs_idx_next <= 5'd0;
            all_consistent_next <= 1'b0;
            
            // Initialize dp array
            for (i = 0; i < 65536; i = i + 1) begin
                dp[i] <= 24'd0;
            end
        end else begin
            state <= next_state;
            switch_idx <= switch_idx_next;
            light_idx <= light_idx_next;
            used_mask <= used_mask_next;
            mask <= mask_next;
            light_bit <= light_bit_next;
            obs_idx <= obs_idx_next;
            all_consistent <= all_consistent_next;
            
            case (state)
                IDLE: begin
                    result <= 24'd0;
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    // Initialize dp array to 0
                    for (i = 0; i < 65536; i = i + 1) begin
                        dp[i] <= 24'd0;
                    end
                end
                
                SETUP: begin
                    // Initialize DP base case
                    dp[16'd0] <= 24'd1;  // One way to assign 0 switches with no lights used
                    cycle_count <= cycle_count + 16'd1;
                end
                
                DP_LOOP: begin
                    cycle_count <= cycle_count + 16'd1;
                    // Reset dp_curr for current mask iteration
                    // We'll write to dp as we compute
                end
                
                CHECK_LIGHT: begin
                    // Check consistency for switch_idx with light_idx
                    switch_bits <= obs_switch[obs_idx];
                    light_bits <= obs_light[obs_idx];
                end
                
                VALID: begin
                    // All observations consistent, add to count
                    // dp[used_mask_next] += dp[used_mask]
                    temp_sum <= {24'd0, dp[used_mask]} + dp[used_mask | light_bit_next];
                end
                
                ADD_RES: begin
                    // Apply modulo
                    if (temp_sum >= MODULO) begin
                        dp[used_mask | light_bit_next] <= temp_sum - MODULO;
                    end else begin
                        dp[used_mask | light_bit_next] <= temp_sum[23:0];
                    end
                end
                
                FINISH: begin
                    result <= dp[(1 << n) - 1];  // All lights used
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    // Combinational next state logic
    always @(*) begin
        next_state = state;
        switch_idx_next = switch_idx;
        light_idx_next = light_idx;
        used_mask_next = used_mask;
        mask_next = mask;
        light_bit_next = light_bit;
        obs_idx_next = obs_idx;
        all_consistent_next = all_consistent;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SETUP;
                    switch_idx_next = 4'd0;
                end
            end
            
            SETUP: begin
                next_state = DP_START;
                switch_idx_next = 4'd0;
                mask_next = 16'd0;
            end
            
            DP_START: begin
                // Start processing current switch
                if (switch_idx >= n) begin
                    next_state = FINISH;
                end else begin
                    next_state = DP_LOOP;
                    used_mask_next = 16'd0;
                    light_idx_next = 4'd0;
                    light_bit_next = 16'd1;
                end
            end
            
            DP_LOOP: begin
                // Iterate over all used_mask values
                if (mask_next >= (1 << n)) begin
                    // Done with all masks for this switch
                    next_state = NEXT_SWITCH;
                end else if (dp[mask] != 24'd0) begin
                    // This mask has valid assignments, try to extend
                    next_state = CHECK_LIGHT;
                    used_mask_next = mask;
                    light_idx_next = 4'd0;
                    light_bit_next = 16'd1;
                    obs_idx_next = 5'd0;
                end else begin
                    // Skip this mask, go to next
                    mask_next = mask + 16'd1;
                end
            end
            
            CHECK_LIGHT: begin
                // Try light_idx
                if (light_idx >= n) begin
                    // Done trying all lights for this switch
                    next_state = DP_LOOP;
                    mask_next = mask + 16'd1;
                end else if ((used_mask & light_bit) != 16'd0) begin
                    // Light already used, try next
                    next_state = CHECK_LIGHT;
                    light_idx_next = light_idx + 4'd1;
                    light_bit_next = light_bit << 1;
                end else begin
                    // Check consistency with all observations
                    if (obs_idx >= m) begin
                        // All observations consistent
                        all_consistent_next = 1'b1;
                        next_state = VALID;
                    end else begin
                        // Check current observation
                        if (((switch_bits >> light_idx) & 16'd1) == ((light_bits >> light_idx) & 16'd1)) begin
                            // Consistent for this observation
                            obs_idx_next = obs_idx + 5'd1;
                        end else begin
                            // Not consistent, try next light
                            all_consistent_next = 1'b0;
                            next_state = CHECK_LIGHT;
                            light_idx_next = light_idx + 4'd1;
                            light_bit_next = light_bit << 1;
                        end
                    end
                end
            end
            
            VALID: begin
                // Add to DP table
                next_state = ADD_RES;
            end
            
            ADD_RES: begin
                // Continue with next light
                next_state = CHECK_LIGHT;
                light_idx_next = light_idx + 4'd1;
                light_bit_next = light_bit << 1;
            end
            
            NEXT_SWITCH: begin
                // Move to next switch
                switch_idx_next = switch_idx + 4'd1;
                mask_next = 16'd0;
                // Copy dp to dp_next (simulated by overwriting)
                // In next DP_START, we'll read from dp and write to dp
                next_state = DP_START;
            end
            
            FINISH: begin
                // Done
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
        
        // Timeout protection
        if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
            next_state = FINISH;
        end
    end

endmodule