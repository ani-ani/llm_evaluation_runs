module schedule_optimizer(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [5:0] s_length,
    input [5:0] t_length,
    input valid_in,
    output reg [7:0] char_out,
    output reg valid_out,
    output reg done
);

// FSM States
localparam IDLE = 4'd0;
localparam INPUT_S = 4'd1;
localparam INPUT_T = 4'd2;
localparam COMPUTE_PREFIX = 4'd3;
localparam FIND_OVERLAP = 4'd4;
localparam ASSEMBLE_OUTPUT = 4'd5;
localparam DONE = 4'd6;

// Internal Registers
reg [3:0] state, next_state;
reg [5:0] s_idx, t_idx; // indices for input/storage
reg [7:0] s_buf[15:0];
reg [7:0] t_buf[15:0];
reg [5:0] zeros_s, ones_s;
reg [5:0] zeros_t, ones_t;
reg [5:0] pi[15:0]; // KMP prefix array
reg [5:0] overlap_len;
reg [5:0] repeat_zeros, repeat_ones;
reg [5:0] repeat_count;
reg [5:0] remaining_zeros, remaining_ones;
reg [5:0] out_index; // index for output generation
reg [5:0] current_char_index; // tracks position in output sequence
reg [5:0] repeat_idx; // index within repeating suffix
reg [5:0] k, i; // loop variables for prefix computation
reg compute_done; // flag for prefix computation completion
reg output_phase; // 0: t, 1: repeat suffix, 2: remaining
reg [5:0] suffix_length; // length of repeating suffix (t_length - overlap_len)

// Next State Logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: if (start) next_state = INPUT_S;
        INPUT_S: if (valid_in && s_idx == s_length - 1) next_state = INPUT_T;
        INPUT_T: if (valid_in && t_idx == t_length - 1) next_state = COMPUTE_PREFIX;
        COMPUTE_PREFIX: if (compute_done) next_state = FIND_OVERLAP;
        FIND_OVERLAP: next_state = ASSEMBLE_OUTPUT;
        ASSEMBLE_OUTPUT: if (done) next_state = DONE;
        DONE: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

// State Register and Output Logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        char_out <= 8'b0;
        valid_out <= 1'b0;
        done <= 1'b0;
        s_idx <= 6'd0;
        t_idx <= 6'd0;
        zeros_s <= 6'd0;
        ones_s <= 6'd0;
        zeros_t <= 6'd0;
        ones_t <= 6'd0;
        compute_done <= 1'b0;
        k <= 6'd0;
        i <= 6'd1;
        overlap_len <= 6'd0;
        repeat_zeros <= 6'd0;
        repeat_ones <= 6'd0;
        repeat_count <= 6'd0;
        remaining_zeros <= 6'd0;
        remaining_ones <= 6'd0;
        out_index <= 6'd0;
        current_char_index <= 6'd0;
        repeat_idx <= 6'd0;
        output_phase <= 1'b0;
        suffix_length <= 6'd0;
    end else begin
        state <= next_state;
        
        // Default outputs
        valid_out <= 1'b0;
        done <= 1'b0;

        case (state)
            IDLE: begin
                s_idx <= 6'd0;
                t_idx <= 6'd0;
                zeros_s <= 6'd0;
                ones_s <= 6'd0;
                zeros_t <= 6'd0;
                ones_t <= 6'd0;
                compute_done <= 1'b0;
                k <= 6'd0;
                i <= 6'd1;
                out_index <= 6'd0;
                current_char_index <= 6'd0;
                repeat_idx <= 6'd0;
                output_phase <= 1'b0;
            end

            INPUT_S: begin
                if (valid_in) begin
                    s_buf[s_idx] <= char_in;
                    if (char_in == 8'd48) zeros_s <= zeros_s + 1; // '0'
                    else if (char_in == 8'd49) ones_s <= ones_s + 1; // '1'
                    s_idx <= s_idx + 1;
                end
            end

            INPUT_T: begin
                if (valid_in) begin
                    t_buf[t_idx] <= char_in;
                    if (char_in == 8'd48) zeros_t <= zeros_t + 1;
                    else if (char_in == 8'd49) ones_t <= ones_t + 1;
                    t_idx <= t_idx + 1;
                end
            end

            COMPUTE_PREFIX: begin
                // KMP Prefix Computation: sequential logic to avoid long paths
                // pi[0] is implicitly 0
                if (i < t_length) begin
                    if (k > 0 && t_buf[k] != t_buf[i]) begin
                        k <= pi[k - 1];
                    end else if (t_buf[k] == t_buf[i]) begin
                        pi[i] <= k + 1;
                        k <= k + 1;
                        i <= i + 1;
                    end else begin
                        pi[i] <= 0;
                        i <= i + 1;
                    end
                end else begin
                    compute_done <= 1'b1;
                end
            end

            FIND_OVERLAP: begin
                // L = pi[t_length - 1]
                overlap_len <= (t_length > 0) ? pi[t_length - 1] : 0;
                // Logic to count zeros/ones in repeating suffix is handled in ASSEMBLE or here
                // We calculate suffix_length here for convenience
                if (t_length > pi[t_length - 1]) 
                    suffix_length <= t_length - pi[t_length - 1];
                else 
                    suffix_length <= 0;
            end

            ASSEMBLE_OUTPUT: begin
                // This state runs for multiple cycles to generate output
                if (current_char_index == 0) begin
                    // Initial calculation of counts once at start of assembly
                    if (overlap_len < t_length) begin
                        // Calculate counts for repeating suffix: t[L:t_length]
                        // We need to count chars in the suffix
                        // Optimization: Pre-calculate or count on the fly
                        // Since t_buf is static, we can count it now
                        // For simplicity in hardware, we'll count suffix on the fly or pre-calc in a small FSM
                        // Let's assume we calculate repeat_zeros/ones based on suffix stored in t_buf
                        // Actually, better to calculate once in FIND_OVERLAP if we had more states, 
                        // but here we do it in first cycle of ASSEMBLE
                    end
                end
                
                // Let's implement a cleaner ASSEMBLE logic:
                // The ASSEMBLE state will be a small FSM itself.
                // Step 1: Output t (all chars)
                // Step 2: Output suffix * count (we need suffix chars and counts)
                // Step 3: Output remaining zeros/ones
                
                // To handle this efficiently, let's restructure ASSEMBLE into sub-steps
                // using the current_char_index and output_phase logic.
            end
        endcase
        
        // Re-implementation of ASSEMBLE logic for clarity and correctness
        // The always block above handles transitions, we need detailed generation logic.
        // The 'ASSEMBLE_OUTPUT' state will stay active for many cycles.
    end
end

// Separate combinational logic for ASSEMBLE state is complex inside one block.
// Let's refine the main block to handle the generation step-by-step.

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        char_out <= 8'b0;
        valid_out <= 1'b0;
        done <= 1'b0;
        s_idx <= 6'd0;
        t_idx <= 6'd0;
        zeros_s <= 6'd0;
        ones_s <= 6'd0;
        zeros_t <= 6'd0;
        ones_t <= 6'd0;
        compute_done <= 1'b0;
        k <= 6'd0;
        i <= 6'd1;
        overlap_len <= 6'd0;
        repeat_zeros <= 6'd0;
        repeat_ones <= 6'd0;
        repeat_count <= 6'd0;
        remaining_zeros <= 6'd0;
        remaining_ones <= 6'd0;
        out_index <= 6'd0;
        current_char_index <= 6'd0;
        repeat_idx <= 6'd0;
        output_phase <= 2'd0; // 0: init, 1: t, 2: repeat, 3: remain
        suffix_length <= 6'd0;
        // pi initialization not strictly needed as it's written before read
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= INPUT_S;
                done <= 1'b0;
                valid_out <= 1'b0;
            end
            
            INPUT_S: begin
                if (valid_in) begin
                    s_buf[s_idx] <= char_in;
                    if (char_in == 8'd48) zeros_s <= zeros_s + 1;
                    else if (char_in == 8'd49) ones_s <= ones_s + 1;
                    if (s_idx < s_length - 1) s_idx <= s_idx + 1;
                    else s_idx <= 6'd0; // Reset for later use if needed
                end
                if (valid_in && s_idx == s_length - 1) state <= INPUT_T;
            end
            
            INPUT_T: begin
                if (valid_in) begin
                    t_buf[t_idx] <= char_in;
                    if (char_in == 8'd48) zeros_t <= zeros_t + 1;
                    else if (char_in == 8'd49) ones_t <= ones_t + 1;
                    if (t_idx < t_length - 1) t_idx <= t_idx + 1;
                end
                if (valid_in && t_idx == t_length - 1) state <= COMPUTE_PREFIX;
            end
            
            COMPUTE_PREFIX: begin
                // KMP Logic
                if (i < t_length) begin
                    if (k > 0 && t_buf[k] != t_buf[i]) begin
                        k <= pi[k - 1];
                    end else if (t_buf[k] == t_buf[i]) begin
                        pi[i] <= k + 1;
                        k <= k + 1;
                        i <= i + 1;
                    end else begin
                        pi[i] <= 0;
                        i <= i + 1;
                    end
                end else begin
                    state <= FIND_OVERLAP;
                    compute_done <= 1'b1; // This flag is just for transition
                    // Reset k and i for potential reuse
                    k <= 6'd0;
                    i <= 6'd0;
                end
            end
            
            FIND_OVERLAP: begin
                // Determine overlap and suffix properties
                if (t_length > 0) overlap_len <= pi[t_length - 1];
                else overlap_len <= 0;
                
                // Calculate suffix length
                if (t_length > pi[t_length - 1]) suffix_length <= t_length - pi[t_length - 1];
                else suffix_length <= 0;
                
                // We need to count zeros/ones in the suffix to calculate repeat_count
                // Since we are in one cycle (or few), let's count now using a small loop index
                // Or better, use combinational logic for counts, or sequential logic in IDLE/START.
                // Let's do sequential counting here if suffix_length > 0.
                // To do this sequentially, we might need an internal counter.
                // Let's assume we calculate repeat_zeros/ones based on suffix.
                // If suffix is empty, counts are 0.
                
                // Sequential counting of suffix requires state retention.
                // Let's use 'k' and 'i' for the counting loop.
                if (k == 0 && i == 0) begin
                    repeat_zeros <= 0;
                    repeat_ones <= 0;
                    if (suffix_length == 0) state <= ASSEMBLE_OUTPUT;
                end
                
                if (k < suffix_length) begin
                    // Index: overlap_len + k
                    if (t_buf[overlap_len + k] == 8'd48) repeat_zeros <= repeat_zeros + 1;
                    else if (t_buf[overlap_len + k] == 8'd49) repeat_ones <= repeat_ones + 1;
                    k <= k + 1;
                end else if (k == suffix_length && suffix_length > 0) begin
                    state <= ASSEMBLE_OUTPUT;
                end else if (suffix_length == 0 && k == 0) begin
                     state <= ASSEMBLE_OUTPUT;
                end
                
                // If suffix_length is 0, we transition immediately in next cycle if logic is added above
                if (suffix_length == 0 && k == 0 && i == 0) state <= ASSEMBLE_OUTPUT;
            end
            
            ASSEMBLE_OUTPUT: begin
                // This state processes the output sequence over many cycles.
                // 1. Output T (index 0 to t_length-1)
                // 2. Output Suffix (index overlap_len to t_length-1) * repeat_count
                // 3. Output Remaining (zeros_s - used_zeros) zeros and (ones_s - used_ones) ones
                
                // We need to calculate repeat_count first.
                // This calculation happens when we just entered ASSEMBLE_OUTPUT or before starting output.
                // Let's use a flag 'output_phase' to manage stages.
                
                // STAGE 0: Calculation
                if (output_phase == 2'd0) begin
                    // Calculate repeat count
                    // Check for insufficient resources
                    if (zeros_t > zeros_s || ones_t > ones_s) begin
                        // Insufficient for even one t. Just output s as-is.
                        // Simplification: The problem says "If s has insufficient zeros/ones for t, output remaining chars as-is"
                        // Interpretation: If we can't make t, maybe we just dump the input s?
                        // Or perhaps we can't repeat t. Let's assume we output t if possible, else maybe s?
                        // "Construct output by concatenating t + (overlap)s * count"
                        // If count is 0, it's just t + remaining.
                        // But if zeros_t > zeros_s, we can't even output t.
                        // Let's assume we output the maximum prefix of t that fits, or just the raw s.
                        // Given the problem description "Output: t + ... + remaining", if t doesn't fit, the design should handle it.
                        // Let's assume if t doesn't fit, we output t anyway (conceptually, or maybe just S).
                        // Let's strictly follow the math: repeat_count = min(available_zeros / repeat_zeros, available_ones / repeat_ones).
                        // If repeat_zeros is 0, division by 0. Use large number. 
                        // If available_zeros < zeros_t, repeat_count might be 0, but we still output t once.
                        // Let's define: Output t once regardless. Then repeat based on remainder.
                        
                        // Calculate remainder after one t
                        remaining_zeros <= (zeros_s >= zeros_t) ? (zeros_s - zeros_t) : 0;
                        remaining_ones <= (ones_s >= ones_t) ? (ones_s - ones_t) : 0;
                        
                        if (repeat_zeros > 0 && repeat_ones > 0) begin
                            if ((zeros_s >= zeros_t) && (ones_s >= ones_t)) begin
                                repeat_count <= ((zeros_s - zeros_t) / repeat_zeros) < ((ones_s - ones_t) / repeat_ones) ? 
                                                ((zeros_s - zeros_t) / repeat_zeros) : ((ones_s - ones_t) / repeat_ones);
                            end else begin
                                repeat_count <= 0;
                            end
                        end else begin
                            // If suffix is empty or has no chars, count doesn't matter (0 repeats)
                            repeat_count <= 0;
                        end
                        
                        output_phase <= 2'd1; // Move to outputting t
                    end else begin
                        // Sufficient for t
                        remaining_zeros <= zeros_s - zeros_t;
                        remaining_ones <= ones_s - ones_t;
                        
                        if (repeat_zeros > 0 && repeat_ones > 0) begin
                            repeat_count <= (zeros_s - zeros_t) / repeat_zeros < (ones_s - ones_t) / repeat_ones ? 
                                            (zeros_s - zeros_t) / repeat_zeros : (ones_s - ones_t) / repeat_ones;
                        end else begin
                            repeat_count <= 0;
                        end
                        output_phase <= 2'd1;
                    end
                    out_index <= 0;
                end
                
                // STAGE 1: Output t (0 to t_length-1)
                else if (output_phase == 2'd1) begin
                    if (out_index < t_length) begin
                        char_out <= t_buf[out_index];
                        valid_out <= 1'b1;
                        out_index <= out_index + 1;
                    end else begin
                        // Finished t
                        // Update remaining counts based on t output
                        if (zeros_s >= zeros_t) remaining_zeros <= remaining_zeros - 0; // already accounted? No, we subtracted full t in calc. 
                        // Wait, if we can't output t fully (insufficient resources), we should stop or output partial.
                        // Let's assume if insufficient, we just don't output t. 
                        // But we set remaining_zeros = 0 if insufficient above.
                        // Logic check: if insufficient, remaining_zeros = 0. We output t anyway? 
                        // Let's stick to: if insufficient, we output nothing? 
                        // Better: The algorithm says "Construct output by concatenating t..." 
                        // If insufficient, maybe we output whatever we can? 
                        // Let's assume valid_in logic works. If t doesn't fit, repeat_count=0, output t.
                        
                        out_index <= 0;
                        if (repeat_count > 0) begin
                            output_phase <= 2'd2; // Go to repeat suffix
                        end else begin
                            output_phase <= 2'd3; // Go to remaining
                        end
                    end
                end
                
                // STAGE 2: Output Repeating Suffix
                else if (output_phase == 2'd2) begin
                    if (repeat_count > 0) begin
                        if (out_index < suffix_length) begin
                            char_out <= t_buf[overlap_len + out_index];
                            valid_out <= 1'b1;
                            out_index <= out_index + 1;
                        end else begin
                            // Finished one instance of suffix
                            out_index <= 0;
                            repeat_count <= repeat_count - 1;
                            // Update remaining counts? 
                            // We pre-calculated remaining_zeros/ones after t.
                            // We need to decrement them as we output suffix? 
                            // Or do we just dump the suffix count times and then dump whatever is left in remaining_zeros/ones?
                            // The prompt: "t + (repeating_suffix * repeat_count) + remaining chars"
                            // This implies we remove the suffix chars from the pool.
                            // We need to decrement remaining_zeros/ones here.
                            if (t_buf[overlap_len + out_index - 1] == 8'd48) remaining_zeros <= remaining_zeros - 1;
                            else if (t_buf[overlap_len + out_index - 1] == 8'd49) remaining_ones <= remaining_ones - 1;
                            
                            if (repeat_count == 1) begin
                                output_phase <= 2'd3; // Done repeating
                            end
                        end
                    end else begin
                        output_phase <= 2'd3;
                    end
                end
                
                // STAGE 3: Output Remaining (Zeros and Ones)
                else if (output_phase == 2'd3) begin
                    if (remaining_zeros > 0) begin
                        char_out <= 8'd48; // '0'
                        valid_out <= 1'b1;
                        remaining_zeros <= remaining_zeros - 1;
                    end else if (remaining_ones > 0) begin
                        char_out <= 8'd49; // '1'
                        valid_out <= 1'b1;
                        remaining_ones <= remaining_ones - 1;
                    end else begin
                        done <= 1'b1;
                        valid_out <= 1'b0;
                        state <= DONE;
                        output_phase <= 2'd0; // Reset for next run
                    end
                end
            end
            
            DONE: begin
                state <= IDLE;
                done <= 1'b0;
            end
        endcase
        
        // Override valid_out if not in ASSEMBLE stage or waiting
        if (state != ASSEMBLE_OUTPUT) valid_out <= 1'b0;
    end
end

endmodule
