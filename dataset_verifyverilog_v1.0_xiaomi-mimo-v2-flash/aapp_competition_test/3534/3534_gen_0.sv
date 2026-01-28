module ScaledSequenceOptimalK(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] seq_in,
    input seq_valid,
    input seq_done,
    output reg [7:0] optimal_k,
    output reg [3:0] max_matches,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] READ_SEQ    = 3'd1;
    localparam [2:0] CALC_K      = 3'd2;
    localparam [2:0] CHECK_K     = 3'd3;
    localparam [2:0] UPDATE_BEST = 3'd4;
    localparam [2:0] DONE_STATE  = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] seq_buffer [0:15];  // Unpacked array for 16 elements
    reg [3:0] seq_len;             // Actual sequence length (N)
    reg [3:0] k_index;             // Index for candidate K list
    reg [7:0] k_list [0:15];       // Candidate K values (max 16 candidates)
    reg [3:0] k_list_size;         // Number of valid K candidates
    reg [3:0] i_idx;               // Index for iterating through sequence
    reg [7:0] current_k;
    reg [3:0] match_count;
    reg [3:0] idx_buffer;          // For storing/reading from buffer
    reg [3:0] calc_idx;            // Index for K calculation
    reg signed [7:0] diff_temp;
    reg [7:0] last_k_stored;
    reg [3:0] match_buffer;        // Temporary match counter for CHECK_K state
    reg k_found;                   // Flag for duplicate K check
    
    // Max cycles for safety
    localparam [11:0] MAX_CYCLES = 12'd2048;
    reg [11:0] cycle_counter;
    reg start_delayed;

    integer i;  // For loops

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            optimal_k <= 8'd0;
            max_matches <= 4'd0;
            done <= 1'b0;
            seq_len <= 4'd0;
            k_index <= 4'd0;
            k_list_size <= 4'd0;
            i_idx <= 4'd0;
            idx_buffer <= 4'd0;
            calc_idx <= 4'd0;
            match_count <= 4'd0;
            match_buffer <= 4'd0;
            current_k <= 8'd0;
            last_k_stored <= 8'd0;
            cycle_counter <= 12'd0;
            start_delayed <= 1'b0;
            // Initialize buffer arrays
            for (i = 0; i < 16; i = i + 1) begin
                seq_buffer[i] <= 8'd0;
                k_list[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            start_delayed <= start;  // Store start pulse
            
            // Cycle counter to prevent infinite loops
            if (state == IDLE && start) begin
                cycle_counter <= 12'd0;
            end else if (state != IDLE && state != DONE_STATE) begin
                cycle_counter <= cycle_counter + 12'd1;
            end

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    // Reset counters/indices
                    seq_len <= 4'd0;
                    k_list_size <= 4'd0;
                    k_index <= 4'd0;
                    idx_buffer <= 4'd0;
                    match_count <= 4'd0;
                    optimal_k <= 8'd0;
                    max_matches <= 4'd0;
                    // Clear arrays
                    for (i = 0; i < 16; i = i + 1) begin
                        seq_buffer[i] <= 8'd0;
                        k_list[i] <= 8'd0;
                    end
                end

                READ_SEQ: begin
                    if (seq_valid && seq_len < 16) begin
                        seq_buffer[seq_len] <= seq_in;
                        seq_len <= seq_len + 4'd1;
                    end
                    if (seq_done && seq_len > 4'd1) begin
                        // Sequence read complete
                        calc_idx <= 4'd0;
                        k_list_size <= 4'd0;
                    end
                end

                CALC_K: begin
                    if (calc_idx < (seq_len - 4'd1)) begin
                        diff_temp <= seq_buffer[calc_idx + 4'd1] - seq_buffer[calc_idx];
                        calc_idx <= calc_idx + 4'd1;
                        
                        // Check and store valid K
                        // Valid K: > 0 and <= 255 (positive difference)
                        // Note: diff_temp is signed [7:0]. Positive means > 0
                        if ((seq_buffer[calc_idx + 4'd1] > seq_buffer[calc_idx]) && 
                            (k_list_size < 16)) begin
                            // Check for duplicate before storing
                            k_found <= 1'b0;
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i < k_list_size && k_list[i] == seq_buffer[calc_idx + 4'd1] - seq_buffer[calc_idx]) begin
                                    k_found <= 1'b1;
                                end
                            end
                            // Only add if not found and within 8-bit range (always true for byte diff)
                            if (!k_found) begin
                                k_list[k_list_size] <= seq_buffer[calc_idx + 4'd1] - seq_buffer[calc_idx];
                                k_list_size <= k_list_size + 4'd1;
                            end
                        end
                    end
                end

                CHECK_K: begin
                    // Simulate playback and count matches
                    // a[0] is always a match (start at a[0])
                    // For i=1 to N-1: play a[i-1] +/- K, compare to a[i]
                    // We track match_buffer
                    
                    if (i_idx == 4'd0) begin
                        // Start new K iteration
                        current_k <= k_list[k_index];
                        match_buffer <= 4'd1;  // First element always matches
                        i_idx <= 4'd1;
                    end else if (i_idx < seq_len) begin
                        // Check if a[i] matches a[i-1] +/- K
                        // Calculate expected values
                        if (seq_buffer[i_idx] > seq_buffer[i_idx - 4'd1]) begin
                            // Should match a[i-1] + K
                            if (seq_buffer[i_idx] == (seq_buffer[i_idx - 4'd1] + current_k)) begin
                                match_buffer <= match_buffer + 4'd1;
                            end
                        end else if (seq_buffer[i_idx] < seq_buffer[i_idx - 4'd1]) begin
                            // Should match a[i-1] - K
                            if (seq_buffer[i_idx] == (seq_buffer[i_idx - 4'd1] - current_k)) begin
                                match_buffer <= match_buffer + 4'd1;
                            end
                        end
                        // If equal, the rule is "play same", so a[i] always matches a[i-1]
                        // (But our code above doesn't explicitly handle this, implicitly it's covered by match increment if we consider equality as match)
                        // Actually, if a[i] == a[i-1], we play a[i-1], so a[i] matches. 
                        // We need to handle this explicitly.
                        if (seq_buffer[i_idx] == seq_buffer[i_idx - 4'd1]) begin
                             match_buffer <= match_buffer + 4'd1;
                        end
                        
                        i_idx <= i_idx + 4'd1;
                    end
                end

                UPDATE_BEST: begin
                    if (match_buffer > max_matches) begin
                        max_matches <= match_buffer;
                        optimal_k <= current_k;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;  // Default stay in current state
        
        case (state)
            IDLE: begin
                if (start) next_state = READ_SEQ;
            end
            
            READ_SEQ: begin
                if (seq_done) begin
                    if (seq_len <= 4'd1) begin
                        next_state = DONE_STATE;  // Invalid sequence length
                    end else begin
                        next_state = CALC_K;
                    end
                end else if (cycle_counter >= MAX_CYCLES) begin
                    next_state = DONE_STATE;  // Safety timeout
                end
            end

            CALC_K: begin
                // Generate K candidates from adjacent differences
                if (calc_idx >= (seq_len - 4'd1)) begin
                    // Check if we found any K candidates
                    if (k_list_size == 4'd0) begin
                        // If no valid K found (all elements equal or descending), K=0 is optimal
                        // But K=0 gives N matches (always equal). 
                        // We handle this by forcing a single K=0 check if list empty.
                        next_state = CHECK_K;
                    end else begin
                        k_index <= 4'd0;
                        i_idx <= 4'd0;  // Reset for simulation
                        next_state = CHECK_K;
                    end
                end else if (cycle_counter >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end
            end

            CHECK_K: begin
                // Run simulation for current K
                if (i_idx >= seq_len) begin
                    // Simulation complete for this K
                    next_state = UPDATE_BEST;
                end else if (cycle_counter >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end
            end

            UPDATE_BEST: begin
                // Move to next K
                if (k_index < (k_list_size - 4'd1)) begin
                    k_index <= k_index + 4'd1;
                    i_idx <= 4'd0;  // Reset for next simulation
                    next_state = CHECK_K;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                if (!start_delayed && !start) begin  // Wait for start to go low
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
        
        // Handle case where CALC_K found no candidates (k_list_size = 0)
        // Special logic: if all elements are equal, K=0 gives N matches.
        // The problem statement says K is derived from differences. If no positive diffs,
        // we should default to K=0 or check K=0 explicitly.
        // Let's add a path to check K=0 if list is empty.
        if (state == CALC_K && calc_idx >= (seq_len - 4'd1) && k_list_size == 4'd0) begin
             // Force check K=0
             k_list[0] <= 8'd0;
             k_list_size <= 4'd1;
        end
    end

endmodule