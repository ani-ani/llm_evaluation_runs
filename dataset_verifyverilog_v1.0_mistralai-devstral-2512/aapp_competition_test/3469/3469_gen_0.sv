module gon_win_probability(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] g_arr,
    input wire [7:0] k_arr,
    input wire [9:0] P,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10000;

    // Internal registers for computation
    reg [7:0] g_pattern;
    reg [7:0] k_pattern;
    reg [9:0] prob_P;
    
    // Markov chain state representation
    reg [7:0] current_state;
    reg [7:0] next_state;
    
    // Transition matrix and probability registers
    reg [15:0] prob_matrix [0:255];
    reg [15:0] current_prob [0:255];
    reg [15:0] next_prob [0:255];
    
    // Temporary registers for computation
    reg [15:0] temp_prob;
    reg [7:0] i, j, k;
    reg [7:0] state_index;
    reg [7:0] new_state;
    reg [7:0] suffix_mask;
    reg [7:0] g_match_mask;
    reg [7:0] k_match_mask;
    reg [7:0] new_suffix;
    reg [7:0] new_g_match;
    reg [7:0] new_k_match;
    reg [7:0] bit_pos;
    reg [7:0] g_len;
    reg [7:0] k_len;
    reg [7:0] max_len;
    reg [7:0] g_bits [0:7];
    reg [7:0] k_bits [0:7];
    reg [7:0] g_prefix [0:7];
    reg [7:0] k_prefix [0:7];
    reg [7:0] g_prefix_mask [0:7];
    reg [7:0] k_prefix_mask [0:7];
    reg [7:0] g_full_mask;
    reg [7:0] k_full_mask;
    reg [7:0] both_mask;
    reg [7:0] g_only_mask;
    reg [7:0] k_only_mask;
    reg [7:0] draw_mask;
    reg [7:0] absorbing_mask;
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize computation registers
            g_pattern <= 8'd0;
            k_pattern <= 8'd0;
            prob_P <= 10'd0;
            current_state <= 8'd0;
            next_state <= 8'd0;
            
            // Initialize probability arrays
            for (i = 0; i < 256; i = i + 1) begin
                prob_matrix[i] <= 16'd0;
                current_prob[i] <= 16'd0;
                next_prob[i] <= 16'd0;
            end
            
            // Initialize temporary registers
            temp_prob <= 16'd0;
            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            state_index <= 8'd0;
            new_state <= 8'd0;
            suffix_mask <= 8'd0;
            g_match_mask <= 8'd0;
            k_match_mask <= 8'd0;
            new_suffix <= 8'd0;
            new_g_match <= 8'd0;
            new_k_match <= 8'd0;
            bit_pos <= 8'd0;
            g_len <= 8'd0;
            k_len <= 8'd0;
            max_len <= 8'd0;
            
            // Initialize pattern arrays
            for (i = 0; i < 8; i = i + 1) begin
                g_bits[i] <= 8'd0;
                k_bits[i] <= 8'd0;
                g_prefix[i] <= 8'd0;
                k_prefix[i] <= 8'd0;
                g_prefix_mask[i] <= 8'd0;
                k_prefix_mask[i] <= 8'd0;
            end
            
            g_full_mask <= 8'd0;
            k_full_mask <= 8'd0;
            both_mask <= 8'd0;
            g_only_mask <= 8'd0;
            k_only_mask <= 8'd0;
            draw_mask <= 8'd0;
            absorbing_mask <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        // Load input patterns
                        g_pattern <= g_arr;
                        k_pattern <= k_arr;
                        prob_P <= P;
                        
                        // Extract pattern lengths
                        g_len <= 8'd0;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (g_pattern[i]) begin
                                g_len <= i + 1'b1;
                            end
                        end
                        
                        k_len <= 8'd0;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (k_pattern[i]) begin
                                k_len <= i + 1'b1;
                            end
                        end
                        
                        max_len <= (g_len > k_len) ? g_len : k_len;
                        
                        // Check if patterns are identical
                        if (g_pattern == k_pattern) begin
                            result <= 16'd0;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Main computation logic
                    // Step 1: Precompute pattern bits and prefix masks
                    for (i = 0; i < 8; i = i + 1) begin
                        g_bits[i] <= g_pattern[i];
                        k_bits[i] <= k_pattern[i];
                    end
                    
                    // Compute prefix masks for g and k
                    g_prefix_mask[0] <= 8'd1;
                    for (i = 1; i < 8; i = i + 1) begin
                        g_prefix_mask[i] <= g_prefix_mask[i-1] << 1 | 1'b1;
                    end
                    
                    k_prefix_mask[0] <= 8'd1;
                    for (i = 1; i < 8; i = i + 1) begin
                        k_prefix_mask[i] <= k_prefix_mask[i-1] << 1 | 1'b1;
                    end
                    
                    // Compute full match masks
                    g_full_mask <= g_prefix_mask[g_len-1];
                    k_full_mask <= k_prefix_mask[k_len-1];
                    both_mask <= g_full_mask & k_full_mask;
                    g_only_mask <= g_full_mask & ~k_full_mask;
                    k_only_mask <= k_full_mask & ~g_full_mask;
                    draw_mask <= both_mask;
                    absorbing_mask <= g_full_mask | k_full_mask;
                    
                    // Step 2: Initialize transition matrix
                    // For each state (suffix + match status)
                    for (state_index = 0; state_index < 256; state_index = state_index + 1) begin
                        // Extract suffix and match status from state
                        suffix_mask <= state_index[7:0];
                        g_match_mask <= state_index[7:0];
                        k_match_mask <= state_index[7:0];
                        
                        // For each possible next bit (0=H, 1=T)
                        for (bit_pos = 0; bit_pos < 2; bit_pos = bit_pos + 1) begin
                            // Compute new suffix
                            new_suffix <= (suffix_mask << 1) | bit_pos;
                            
                            // Update match status for g
                            new_g_match <= (g_match_mask << 1) | bit_pos;
                            if (new_g_match == g_full_mask) begin
                                new_g_match <= g_full_mask;
                            end else begin
                                // Check if new suffix matches g prefix
                                for (i = 0; i < g_len; i = i + 1) begin
                                    if (new_suffix[i:0] == g_prefix[i]) begin
                                        new_g_match <= g_prefix_mask[i];
                                    end
                                end
                            end
                            
                            // Update match status for k
                            new_k_match <= (k_match_mask << 1) | bit_pos;
                            if (new_k_match == k_full_mask) begin
                                new_k_match <= k_full_mask;
                            end else begin
                                // Check if new suffix matches k prefix
                                for (i = 0; i < k_len; i = i + 1) begin
                                    if (new_suffix[i:0] == k_prefix[i]) begin
                                        new_k_match <= k_prefix_mask[i];
                                    end
                                end
                            end
                            
                            // Compute new state
                            new_state <= new_suffix | new_g_match | new_k_match;
                            
                            // Compute transition probability
                            if (bit_pos == 1'b0) begin
                                temp_prob <= prob_P;
                            end else begin
                                temp_prob <= 1000 - prob_P;
                            end
                            
                            // Store transition probability
                            prob_matrix[state_index] <= temp_prob;
                        end
                    end
                    
                    // Step 3: Iterative probability computation
                    // Initialize current probabilities
                    current_prob[0] <= 16'd256; // Q8.8 representation of 1.0
                    for (i = 1; i < 256; i = i + 1) begin
                        current_prob[i] <= 16'd0;
                    end
                    
                    // Perform iterations
                    for (i = 0; i < 1000; i = i + 1) begin
                        // Reset next probabilities
                        for (j = 0; j < 256; j = j + 1) begin
                            next_prob[j] <= 16'd0;
                        end
                        
                        // Update probabilities
                        for (j = 0; j < 256; j = j + 1) begin
                            if (current_prob[j] != 16'd0) begin
                                // For each possible transition
                                for (k = 0; k < 2; k = k + 1) begin
                                    // Compute new state
                                    new_state <= (j << 1) | k;
                                    
                                    // Compute transition probability
                                    if (k == 1'b0) begin
                                        temp_prob <= prob_P;
                                    end else begin
                                        temp_prob <= 1000 - prob_P;
                                    end
                                    
                                    // Update next probability
                                    next_prob[new_state] <= next_prob[new_state] + 
                                        (current_prob[j] * temp_prob) >> 10;
                                end
                            end
                        end
                        
                        // Copy next probabilities to current
                        for (j = 0; j < 256; j = j + 1) begin
                            current_prob[j] <= next_prob[j];
                        end
                    end
                    
                    // Step 4: Compute final result
                    // Sum probabilities of states where g wins
                    result <= 16'd0;
                    for (i = 0; i < 256; i = i + 1) begin
                        if ((i & g_full_mask) && !(i & k_full_mask)) begin
                            result <= result + current_prob[i];
                        end
                    end
                    
                    // Clamp result to Q8.8 range
                    if (result > 16'd65535) begin
                        result <= 16'd65535;
                    end
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule