module subseq_hash (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] B,
    input wire [15:0] M,
    input wire [9:0] K,
    input wire [7:0] arr [0:9],
    output reg [31:0] hash_out,
    output reg valid,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] INIT       = 4'd1;
    localparam [3:0] GEN_MASK   = 4'd2;
    localparam [3:0] COMPARE    = 4'd3;
    localparam [3:0] INSERT     = 4'd4;
    localparam [3:0] CALC_HASH  = 4'd5;
    localparam [3:0] OUTPUT     = 4'd6;
    localparam [3:0] FINISH     = 4'd7;
    localparam [3:0] WAIT       = 4'd8;

    // Registers
    reg [3:0] state, next_state;
    reg [10:0] mask_gen;        // Generates masks 1 to 1023 (2^10 - 1)
    reg [10:0] best_masks [0:9]; // Buffer for K masks (max 10)
    reg [31:0] best_hashes [0:9]; // Buffer for K hashes
    reg [3:0] buffer_cnt;       // Current number of items in buffer (0 to K)
    reg [31:0] current_hash;
    reg [10:0] current_mask;
    reg [3:0] i, j;             // Loop counters
    reg [9:0] cycle_count;      // Timeout safety
    
    // Comparison state
    reg [3:0] cmp_idx;
    reg cmp_a_valid, cmp_b_valid;
    reg [7:0] cmp_a_val, cmp_b_val;
    reg cmp_result;             // 1 if A < B (lexicographically)
    reg cmp_done;
    reg cmp_a_ended, cmp_b_ended;
    
    // Hash calculation state
    reg [31:0] hash_acc;
    reg [10:0] hash_mask;
    reg [3:0] hash_idx;
    reg [15:0] power_of_B;
    reg [1:0] hash_step;        // 0: calc pow, 1: mul, 2: add

    integer k; // Helper for loops

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = INIT;
            INIT: next_state = GEN_MASK;
            GEN_MASK: begin
                if (mask_gen >= 11'd1023) next_state = OUTPUT;
                else next_state = COMPARE;
            end
            COMPARE: begin
                if (cmp_done) begin
                    if (cmp_result) next_state = INSERT;
                    else next_state = GEN_MASK;
                end else begin
                    next_state = COMPARE;
                end
            end
            INSERT: next_state = GEN_MASK;
            CALC_HASH: begin
                if (hash_step == 2 && hash_idx >= 4'd10) next_state = GEN_MASK;
                else next_state = CALC_HASH;
            end
            OUTPUT: begin
                if (buffer_cnt == 0) next_state = FINISH;
                else next_state = WAIT;
            end
            WAIT: next_state = OUTPUT;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            done <= 1'b0;
            mask_gen <= 11'd0;
            buffer_cnt <= 4'd0;
            cycle_count <= 10'd0;
            for (k = 0; k < 10; k = k + 1) begin
                best_masks[k] <= 11'd0;
                best_hashes[k] <= 32'd0;
            end
        end else begin
            valid <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    mask_gen <= 11'd0;
                    buffer_cnt <= 4'd0;
                    cycle_count <= 10'd0;
                    cmp_done <= 1'b0;
                end

                INIT: begin
                    // Initialize comparison logic
                    cmp_done <= 1'b0;
                end

                GEN_MASK: begin
                    // Increment mask
                    if (mask_gen < 11'd1023) begin
                        mask_gen <= mask_gen + 11'd1;
                    end
                    // Reset comparison for next iteration
                    cmp_done <= 1'b0;
                    cmp_idx <= 4'd0;
                    cmp_a_ended <= 1'b0;
                    cmp_b_ended <= 1'b0;
                    // Reset hash calc trigger
                    if (mask_gen != 0 && !cmp_result && buffer_cnt < K[3:0]) begin
                        // If we decided not to insert (because buffer not full), trigger hash calc
                        // Actually, we only care about hash for items we insert.
                        // But we need to insert candidates if buffer < K.
                    end
                end

                COMPARE: begin
                    // Iterate through array indices 0 to 9
                    if (cmp_idx < 4'd10) begin
                        // Check if A (current_mask) has this bit
                        if (current_mask[cmp_idx]) begin
                            cmp_a_valid <= 1'b1;
                            cmp_a_val <= arr[cmp_idx];
                        end else begin
                            cmp_a_valid <= 1'b0;
                        end
                        // Check if B (best_masks[buffer_cnt-1]) has this bit
                        if (buffer_cnt > 0 && best_masks[buffer_cnt-1][cmp_idx]) begin
                            cmp_b_valid <= 1'b1;
                            cmp_b_val <= arr[cmp_idx];
                        end else begin
                            cmp_b_valid <= 1'b0;
                        end
                        
                        // Logic: Compare valid bits
                        if (cmp_a_valid && !cmp_b_valid) begin
                            cmp_result <= 1'b0; // A is longer/mismatch, B wins if shorter prefix
                            cmp_done <= 1'b1;
                        end else if (!cmp_a_valid && cmp_b_valid) begin
                            cmp_result <= 1'b1; // B is longer/mismatch, A wins if shorter prefix
                            cmp_done <= 1'b1;
                        end else if (cmp_a_valid && cmp_b_valid) begin
                            if (cmp_a_val < cmp_b_val) begin
                                cmp_result <= 1'b1;
                                cmp_done <= 1'b1;
                            end else if (cmp_a_val > cmp_b_val) begin
                                cmp_result <= 1'b0;
                                cmp_done <= 1'b1;
                            end else begin
                                cmp_idx <= cmp_idx + 4'd1;
                            end
                        end else begin
                            // Neither valid at this index (should not happen if indices match)
                            cmp_idx <= cmp_idx + 4'd1;
                        end
                    end else begin
                        // Reached end of array for both (equal so far)
                        // A is smaller only if it is strictly shorter (implies masked bits exhausted earlier)
                        // But since we iterate 0..9, if they matched all 10, they are equal.
                        cmp_result <= 1'b0; // Equal means not smaller
                        cmp_done <= 1'b1;
                    end
                end

                INSERT: begin
                    // Insert current_mask into buffer.
                    // Shift elements down if buffer is full
                    if (buffer_cnt >= K[3:0]) begin
                        // Remove max (which is at index 0 in this sorted list)
                        // Shift 1..K-1 to 0..K-2
                        for (int m = 0; m < 9; m = m + 1) begin
                            if (m < K[3:0] - 1) begin
                                best_masks[m] <= best_masks[m+1];
                                best_hashes[m] <= best_hashes[m+1];
                            end
                        end
                        // Insert at end (K-1)
                        best_masks[K[3:0]-1] <= mask_gen;
                        // Hash calculation will happen later or now?
                        // We need to calculate hash for the new item.
                        // Set state to CALC_HASH
                        current_mask <= mask_gen;
                        buffer_cnt <= K[3:0]; // Still full
                    end else begin
                        // Buffer not full, just append
                        best_masks[buffer_cnt] <= mask_gen;
                        buffer_cnt <= buffer_cnt + 4'd1;
                        current_mask <= mask_gen;
                    end
                    // Prepare hash calculation
                    hash_step <= 2'b0;
                    hash_idx <= 4'd0;
                    hash_acc <= 32'd0;
                    power_of_B <= 16'd1; // B^0 = 1
                end

                CALC_HASH: begin
                    // We need to compute hash for current_mask
                    // Hash: sum v_i * B^(p-1) ... v_p * B^0 ?
                    // Standard poly: h = v0*B^(k-1) + ... + v_{k-1}*B^0
                    // Let's scan array 0..9.
                    // If bit is set, multiply accumulator by B and add value.
                    // h = 0; for each v: h = h*B + v
                    
                    if (hash_step == 2'b0) begin
                        // Check bit
                        if (current_mask[hash_idx]) begin
                            // h = h * B + v
                            // Multiply hash_acc (32-bit) by B (16-bit)
                            hash_acc <= (hash_acc * B) + arr[hash_idx];
                        end
                        hash_idx <= hash_idx + 4'd1;
                        hash_step <= 2'b1;
                    end else if (hash_step == 2'b1) begin
                        // Wait for multiply/add to settle (if needed, or just combinational)
                        // In Verilog, always block is sequential, so it's already done.
                        // Just move to next or finish.
                        if (hash_idx >= 4'd10) begin
                            // Store result
                            // Find which buffer slot corresponds to current_mask
                            // Since we just inserted/updated, we need to find it.
                            // Actually, we track insertion index in INSERT.
                            // Let's just overwrite the last touched slot.
                            // But the buffer might have shifted.
                            // Simplified: We compute hash and store it directly in INSERT state logic if possible,
                            // or update a temporary register and copy back.
                            // Let's update the hash array.
                            // We need to know the index in best_masks that matches current_mask.
                            // Search best_masks for current_mask.
                            for (int m = 0; m < 10; m = m + 1) begin
                                if (m < K[3:0] && best_masks[m] == current_mask) begin
                                    best_hashes[m] <= hash_acc;
                                end
                            end
                            hash_step <= 2'b10;
                        end else begin
                            hash_step <= 2'b0;
                        end
                    end else begin
                        // Done
                    end
                end

                OUTPUT: begin
                    // Output hashes from buffer (sorted lexicographically ascending)
                    // Buffer is sorted such that best_masks[0] is smallest.
                    // We output from index 0 to K-1.
                    if (buffer_cnt > 0) begin
                        hash_out <= best_hashes[0];
                        valid <= 1'b1;
                        // Shift buffer down
                        for (int m = 0; m < 9; m = m + 1) begin
                            if (m < buffer_cnt - 1) begin
                                best_masks[m] <= best_masks[m+1];
                                best_hashes[m] <= best_hashes[m+1];
                            end
                        end
                        buffer_cnt <= buffer_cnt - 4'd1;
                    end
                    cycle_count <= cycle_count + 10'd1;
                    if (cycle_count > 10'd1000) done <= 1'b1; // Safety timeout
                end

                WAIT: begin
                    // Wait one cycle for output valid pulse
                end

                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule