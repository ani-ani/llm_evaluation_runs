module ExpectedScoreCalculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] data_in,
    input wire data_valid,
    input wire data_last,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] PARSE_META = 3'd1;
    localparam [2:0] PARSE_Q    = 3'd2;
    localparam [2:0] BUILD_TRIE = 3'd3;
    localparam [2:0] DP_COMPUTE = 3'd4;
    localparam [2:0] DP_FINAL   = 3'd5;
    localparam [2:0] FINISH     = 3'd6;

    // Regs and state
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Input parsing regs
    reg [7:0] total_time;
    reg [7:0] num_questions;
    reg [7:0] current_q;
    reg [7:0] byte_counter;
    reg [7:0] word_len;
    reg [2:0] parse_phase; // 0: wait q, 1: read len, 2: read words, 3: read answer
    reg [4:0] word_idx;

    // Trie node structure (BRAM representation)
    // 32 nodes max. Node 0 is root.
    // Each node: 16 children (8-bit each) + 1 count byte = 17 bytes
    // We store: child[0..15] (8-bit), count (8-bit)
    // Using distributed RAM (register array) for simplicity and synthesizability
    reg [7:0] trie_child [0:31][0:15]; // 32 nodes, 16 children each
    reg [7:0] trie_count [0:31];       // 32 nodes, count of questions
    reg [4:0] node_ptr;                // Current node index during construction
    reg [4:0] next_node_idx;           // Next available node index

    // DP computation regs
    // DP table: 32 nodes x (T+1) entries. T max 8. So 32 x 9 = 288 entries.
    // Each entry is 16-bit Q8.8.
    reg [15:0] dp_table [0:31][0:8]; // Nodes x Time
    reg [7:0] tau; // Current time step for DP (1 to T)
    reg [4:0] node_iter; // Node iterator
    reg [7:0] k; // Question count for current node
    reg [15:0] score_answer;
    reg [15:0] score_wait;
    reg [15:0] prob_numer; // count_child
    reg [15:0] prob_denom; // k
    reg [15:0] dp_child;
    reg [15:0] mult_result;
    reg [15:0] sum_wait;
    reg [3:0] child_idx; // 0 to 15
    reg child_found;
    reg [15:0] root_dp_prev;

    // Helper for division (1/k approximation for k=1..8)
    // Q8.8: 1/k = 256 / k. Use table for k=1..8
    reg [15:0] inv_k_table [0:7]; // index 0 unused, 1..8 valid
    initial begin
        inv_k_table[1] = 16'd256; // 1.0
        inv_k_table[2] = 16'd128; // 0.5
        inv_k_table[3] = 16'd85;  // ~0.333
        inv_k_table[4] = 16'd64;  // 0.25
        inv_k_table[5] = 16'd51;  // 0.2
        inv_k_table[6] = 16'd43;  // ~0.166
        inv_k_table[7] = 16'd37;  // ~0.143
        inv_k_table[8] = 16'd32;  // 0.125
    end

    // Temporary storage for word IDs (max 4 words per question)
    reg [7:0] temp_word_ids [0:3];
    reg [7:0] temp_answer_id;

    integer i, j;

    // Next state logic and sequential block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize regs
            total_time <= 8'd0;
            num_questions <= 8'd0;
            current_q <= 8'd0;
            byte_counter <= 8'd0;
            word_len <= 8'd0;
            parse_phase <= 3'd0;
            word_idx <= 5'd0;
            node_ptr <= 5'd0;
            next_node_idx <= 5'd1; // Root is 0
            tau <= 8'd0;
            node_iter <= 5'd0;
            child_idx <= 4'd0;
            
            // Initialize trie arrays (using for loops - synthesizable)
            for (i = 0; i < 32; i = i + 1) begin
                trie_count[i] <= 8'd0;
                for (j = 0; j < 16; j = j + 1) begin
                    trie_child[i][j] <= 8'hFF;
                end
            end
            
            // Initialize DP table
            for (i = 0; i < 32; i = i + 1) begin
                for (j = 0; j < 9; j = j + 1) begin
                    dp_table[i][j] <= 16'd0;
                end
            end
            
            for (i = 0; i < 4; i = i + 1) begin
                temp_word_ids[i] <= 8'd0;
            end
            temp_answer_id <= 8'd0;
            
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        parse_phase <= 3'd1; // Start with meta
                        byte_counter <= 8'd0;
                        current_q <= 8'd0;
                        word_idx <= 5'd0;
                    end
                end

                PARSE_META: begin
                    if (data_valid) begin
                        if (byte_counter == 8'd0) total_time <= data_in;
                        else if (byte_counter == 8'd1) num_questions <= data_in;
                        
                        byte_counter <= byte_counter + 8'd1;
                        
                        if (byte_counter >= 8'd1) begin
                            parse_phase <= 3'd2; // Go to parse questions
                            byte_counter <= 8'd0;
                            word_len <= 8'd0;
                            word_idx <= 5'd0;
                        end
                    end
                end

                PARSE_Q: begin
                    if (data_valid) begin
                        if (parse_phase == 3'd2) begin // Read word length
                            word_len <= data_in;
                            parse_phase <= 3'd3;
                            word_idx <= 5'd0;
                        end else if (parse_phase == 3'd3) begin // Read words
                            temp_word_ids[word_idx] <= data_in;
                            word_idx <= word_idx + 5'd1;
                            if (word_idx + 5'd1 >= word_len) begin
                                parse_phase <= 3'd4; // Next phase: answer
                            end
                        end else if (parse_phase == 3'd4) begin // Read answer
                            temp_answer_id <= data_in;
                            parse_phase <= 3'd2; // Back to next question or finish
                            byte_counter <= 8'd0;
                            current_q <= current_q + 8'd1;
                        end
                    end
                    
                    if (data_last && data_valid) begin
                        // Finished reading stream
                        parse_phase <= 3'd0;
                    end
                end

                BUILD_TRIE: begin
                    // Insert current question's words into trie
                    // This state processes one question per cycle (or logic split)
                    // Here we assume we process one question fully per cycle for simplicity
                    // since max 32 nodes, max 32 words total.
                    
                    // Increment count at root
                    trie_count[5'd0] <= trie_count[5'd0] + 8'd1;
                    
                    // Insert words
                    if (word_len > 0) begin
                        for (i = 0; i < 4; i = i + 1) begin
                            if (i < word_len) begin
                                // Recursive insertion logic simulated iteratively
                                // We need to track node pointer during insertion
                                // For this simplified version, we assume we build as we read
                                // but since we read all data first, we need to store it or process on fly.
                                // Let's process on fly in PARSE_Q state actually.
                                // So we modify PARSE_Q to insert into trie directly.
                            end
                        end
                    end
                    
                    // Since we moved insertion to parse, this state is largely skipped or used for finalizing.
                end

                DP_COMPUTE: begin
                    // DP Computation
                    // We iterate tau from 1 to T, and nodes 0 to N-1
                    // We use cycle_count to control iteration depth if needed, 
                    // but here we do one step per cycle to keep it simple and verifyable.
                    
                    // We need to handle the DP logic carefully.
                    // Logic for current (tau, node_iter):
                    
                    k = trie_count[node_iter];
                    
                    if (k > 0) begin
                        // Option 1: Answer Now
                        // score_answer = (1.0 / k) + DP[tau-1][root]
                        // 1.0 / k is approx 256 / k
                        root_dp_prev = dp_table[5'd0][tau - 8'd1];
                        if (k <= 8) begin
                            score_answer = inv_k_table[k] + root_dp_prev;
                        end else begin
                            score_answer = root_dp_prev; // Fallback
                        end
                        
                        // Option 2: Listen
                        // score_wait = sum(child_count / k * DP[tau-1][child])
                        sum_wait = 16'd0;
                        for (j = 0; j < 16; j = j + 1) begin
                            if (trie_child[node_iter][j] != 8'hFF) begin
                                prob_numer = trie_count[trie_child[node_iter][j]];
                                dp_child = dp_table[trie_child[node_iter][j]][tau - 8'd1];
                                // prob_numer / k * dp_child
                                // = (prob_numer * dp_child) / k
                                // prob_numer is usually small (count of questions in subtree)
                                // dp_child is Q8.8
                                // Result should be Q8.8
                                // (prob_numer * dp_child) is roughly Q8.8 * Q8.8 = Q16.16
                                // We need to divide by k and keep Q8.8
                                // (prob_numer * dp_child) >> 8 (to get Q8.8) / k
                                // Or: (prob_numer * dp_child) / (k * 256)
                                
                                mult_result = (prob_numer * dp_child) >> 8; // Rough scaling
                                if (k > 0) begin
                                    // Division by k
                                    if (k == 1) mult_result = mult_result;
                                    else if (k == 2) mult_result = mult_result >> 1;
                                    else if (k == 3) mult_result = (mult_result * 85) >> 8;
                                    else if (k == 4) mult_result = mult_result >> 2;
                                    else if (k == 5) mult_result = (mult_result * 51) >> 8;
                                    else if (k == 6) mult_result = (mult_result * 43) >> 8;
                                    else if (k == 7) mult_result = (mult_result * 37) >> 8;
                                    else if (k == 8) mult_result = mult_result >> 3;
                                    else mult_result = mult_result / k;
                                end
                                sum_wait = sum_wait + mult_result;
                            end
                        end
                        score_wait = sum_wait;
                        
                        // Max operation
                        if (score_answer > score_wait) begin
                            dp_table[node_iter][tau] <= score_answer;
                        end else begin
                            dp_table[node_iter][tau] <= score_wait;
                        end
                    end else begin
                        // No questions here, value is 0 (already initialized)
                    end
                end

                DP_FINAL: begin
                    // Just pass through, result assigned in combinational block
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = PARSE_META;
            end
            
            PARSE_META: begin
                // Wait for data valid handled in seq block, transition when ready
                if (data_valid && byte_counter >= 8'd1) next_state = PARSE_Q;
            end
            
            PARSE_Q: begin
                // We need to detect when parsing is done.
                // We process data when data_valid is high.
                // If we just finished reading an answer, we check if we are done with all questions.
                // And if data_last is high.
                // Since this is stream based, we transition to BUILD_TRIE/DP when data_last is seen.
                
                // Logic: if we finished a question (parse_phase went 4 -> 2) AND (current_q == num_questions)
                // OR if we are in phase 4 and data_last is high (though spec says data_last indicates last byte)
                
                // To make it robust: if data_last is asserted and we consumed it, transition.
                // But we need to handle the case where data_last arrives with the answer byte.
                // We'll rely on a flag or counter.
                
                // Let's use a state transition condition based on completion.
                // If current_q == num_questions AND we have processed the answer for the last question
                // OR if num_questions is 0.
                
                if (num_questions == 0) begin
                     next_state = BUILD_TRIE; // Skip parsing
                end else if (current_q >= num_questions && parse_phase == 3'd2) begin
                     // We just finished a question and are waiting for next, but we are done.
                     // Or wait, if current_q == num_questions, we processed num_questions (0 to N-1)
                     // So if current_q == num_questions, we are done.
                     next_state = BUILD_TRIE;
                end
                
                // Also check data_last flag to force transition if stream ends early
                // (Though ideally we read exactly the bytes)
                if (data_last && data_valid) begin
                     next_state = BUILD_TRIE;
                end
            end

            BUILD_TRIE: begin
                // One cycle to finalize if needed, or jump to DP
                // If num_questions == 0, DP is just 0.
                // We can just go to DP_COMPUTE.
                // We need to setup DP loops.
                next_state = DP_COMPUTE;
            end

            DP_COMPUTE: begin
                // We need to iterate T * N times.
                // N = next_node_idx (number of active nodes)
                // T = total_time
                
                // State tracking variables:
                // We can use node_iter and tau to iterate.
                // If we update node_iter and tau in combinational logic or next state?
                // Let's update them in the sequential block but check completion here.
                
                // Logic to advance iterators:
                // node_iter increments. If node_iter reaches next_node_idx, reset node_iter and increment tau.
                // If tau reaches total_time + 1, we are done.
                
                // We perform calculation for (tau, node_iter) in this cycle.
                // So we need to update indices for the NEXT cycle.
                
                // If tau > total_time: done
                if (tau > total_time) begin
                    next_state = DP_FINAL;
                end else begin
                    // We iterate nodes. 
                    // Actually, we should handle the loop updates.
                    // We'll check if we processed all nodes for current tau.
                    // If node_iter >= next_node_idx - 1 (since we just processed node_iter)
                    // Wait, the sequential block computes dp_table[node_iter][tau].
                    // So we increment node_iter. If node_iter wraps, increment tau.
                    
                    // Let's do the update logic in combinational block for next state/indices.
                    // But indices (tau, node_iter) are regs updated in seq block.
                    // We'll check if we finished ALL work.
                    
                    // Work remaining if tau <= total_time.
                    // But we might have a specific case where num_questions=0 -> total_time might be read but no questions.
                    // DP will be 0.
                    
                    // We need to calculate next values.
                    // Let's assume we do one step per cycle.
                    // Next (tau, node_iter) logic:
                    // If node_iter < next_node_idx - 1: next_node = node_iter + 1
                    // Else: next_node = 0, next_tau = tau + 1
                    
                    // We check completion in combinational block:
                    if (tau > total_time) begin
                        next_state = DP_FINAL;
                    end else begin
                        // Keep iterating
                        next_state = DP_COMPUTE;
                    end
                end
            end

            DP_FINAL: begin
                // Result is DP[total_time][0]
                // If total_time is 0, result is 0.
                next_state = FINISH;
            end

            FINISH: begin
                // Stay in FINISH for one cycle to assert done
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
        
        // Cycle limit safety
        if (cycle_count >= MAX_CYCLES) next_state = IDLE;
    end

    // Iterator Updates (Logic specific for DP)
    // Since we can't put always block inside always block, we handle iterator logic here
    // or merge into the main sequential block. 
    // The instructions say "Use always block for sequential logic".
    // Let's integrate iterator updates into the main always block.
    
    // We need a separate always block or combinational logic to drive the iterator updates
    // based on current state.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tau <= 8'd0;
            node_iter <= 5'd0;
        end else begin
            if (state == BUILD_TRIE) begin
                // Setup for DP
                tau <= 8'd1; // Start at tau=1
                node_iter <= 5'd0;
            end else if (state == DP_COMPUTE) begin
                // Update iterators
                if (node_iter < next_node_idx - 5'd1) begin
                    node_iter <= node_iter + 5'd1;
                end else begin
                    node_iter <= 5'd0;
                    if (tau < total_time) begin
                        tau <= tau + 8'd1;
                    end else begin
                        tau <= tau + 8'd1; // This makes tau > total_time next cycle
                    end
                end
            end
        end
    end

    // TRIE INSERTION LOGIC (Integrated into PARSE_Q)
    // We need to handle the insertion when we have a full word set for a question.
    // Since we store temp_word_ids, we need to process them.
    // This is tricky in a single cycle. Let's add a small sub-state or use the next_state logic.
    // 
    // Re-reading the spec: "After reading all bytes (data_last asserted), the module builds a trie."
    // This implies we buffer inputs, then build, then DP.
    // So PARSE_Q should just store data. BUILD_TRIE should construct the structure.
    // However, we need to know the structure to compute DP (child pointers).
    // 
    // Let's change strategy: PARSE_Q stores word IDs in a buffer (circular or linear).
    // Then BUILD_TRIE processes the buffer to fill trie_child and trie_count.
    // 
    // Buffer size: 50 bytes max. Words: 32 max.
    // Let's use a simple linear buffer for word IDs.
    
    reg [7:0] word_buffer [0:31];
    reg [4:0] wbuf_wr_ptr;
    reg [4:0] wbuf_rd_ptr;
    reg [4:0] words_in_buffer;
    
    // Update buffer logic in PARSE_Q state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wbuf_wr_ptr <= 5'd0;
            words_in_buffer <= 5'd0;
        end else begin
            if (state == IDLE && start) begin
                wbuf_wr_ptr <= 5'd0;
                words_in_buffer <= 5'd0;
                wbuf_rd_ptr <= 5'd0;
            end
            
            if (state == PARSE_Q && data_valid) begin
                if (parse_phase == 3'd3) begin // Reading words
                    word_buffer[wbuf_wr_ptr] <= data_in;
                    wbuf_wr_ptr <= wbuf_wr_ptr + 5'd1;
                    words_in_buffer <= words_in_buffer + 5'd1;
                end
            end
        end
    end

    // Trie Construction Logic in BUILD_TRIE state
    // We need to iterate through the buffer and build the trie.
    // We'll use a state variable or iterate through all words in buffer.
    // Since words_in_buffer might be up to 32, we can do one word per cycle.
    // We need to track which question we are inserting (to know word count).
    // 
    // Problem: We lost the info about which words belong to which question in the buffer (only count).
    // We need to store word counts per question or store metadata.
    // 
    // Let's store question metadata: 
    // question_word_counts[0..7] (max 8 questions)
    reg [2:0] question_word_counts [0:7];
    reg [3:0] q_meta_idx;
    
    // Updated Parse Logic to capture question metadata
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q_meta_idx <= 4'd0;
        end else begin
            if (state == IDLE && start) begin
                q_meta_idx <= 4'd0;
            end
            if (state == PARSE_Q && data_valid) begin
                if (parse_phase == 3'd2) begin // Read length
                    // data_in is length L_i
                    question_word_counts[q_meta_idx] <= data_in[2:0]; // max 4
                    q_meta_idx <= q_meta_idx + 4'd1;
                end
            end
        end
    end

    // BUILD_TRIE state machine details
    reg [4:0] build_word_idx; // Index into word_buffer
    reg [3:0] build_q_idx;    // Index into questions
    reg [3:0] build_w_in_q;   // Word index within current question
    reg [4:0] current_node;   // Node we are at during insertion
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            build_word_idx <= 5'd0;
            build_q_idx <= 4'd0;
            build_w_in_q <= 4'd0;
            current_node <= 5'd0;
        end else begin
            if (state == BUILD_TRIE) begin
                // We need to process all questions.
                // Loop structure in hardware: 
                // If build_q_idx < num_questions:
                //   Process word build_w_in_q of this question.
                //   Lookup child. If absent, allocate new node.
                //   Move to child.
                //   Increment build_w_in_q.
                //   If build_w_in_q == question_word_counts[build_q_idx]:
                //     Increment count at final node.
                //     Reset current_node to 0.
                //     Increment build_q_idx.
                //     Reset build_w_in_q.
                //     Advance build_word_idx by word count.
                
                // Single cycle implementation logic:
                // This might take many cycles. We stay in BUILD_TRIE until done.
                
                // We execute one step per cycle.
                if (build_q_idx < num_questions) begin
                    if (build_w_in_q < question_word_counts[build_q_idx]) begin
                        // Insert one word
                        // Word ID is at word_buffer[build_word_idx]
                        // Current node is 'current_node'
                        // Check trie_child[current_node][word_id]
                        // If FF, allocate: trie_child[current_node][word_id] = next_node_idx++
                        // Move current_node = trie_child[current_node][word_id]
                        // Increment build_w_in_q, build_word_idx
                        
                        // NOTE: This requires a combinational lookup or registered.
                        // Since we are in a clocked block, we need to use the registered values.
                        // We can do the lookup/comparison.
                        
                        // Optimization: We can't easily iterate 256 checks in one cycle.
                        // We map word_id to child index directly? No, word_id is 0-255, child slots are 0-15.
                        // Spec says: "child pointers for possible next words (0..255, limited to 16 slots)"
                        // This implies we need a hash or mapping to fit 256 IDs into 16 slots.
                        // OR, the "16 slots" means 16 children pointers total, storing the actual word ID?
                        // "Each trie node stores: - child pointers for possible next words (0..255, limited to 16 slots)"
                        // Usually trie nodes have fixed slots (e.g., 'a'..'z'). Here words are 0..255.
                        // 16 slots is small. 
                        // Let's assume the slots are indexed by word_id % 16 or similar?
                        // No, that's ambiguous. 
                        // Let's look at "BRAM representation" in notes: 16 children (8-bit each).
                        // This means we store up to 16 children. We need to check if a word ID matches a slot.
                        // This is inefficient for 256 IDs. 
                        // 
                        // ALTERNATIVE: The "16 slots" might refer to the depth/width constraint.
                        // Let's assume a simple direct mapping: word_id is the index if < 16, else wrap?
                        // OR, maybe we just have 16 slots total for all children of a node.
                        // We need to search linearly (up to 16) to find if word_id exists.
                        
                        // Since we have 1 cycle per word insertion, we can do linear search in 16 slots.
                        // But 16 slots * 1 cycle = 16 cycles. 
                        // Total words <= 32. Total cycles <= 32 * 16 = 512. 
                        // Max cycles allowed 200. 
                        // We need to optimize.
                        
                        // Re-read: "Each trie node stores: - child pointers for possible next words (0..255, limited to 16 slots)"
                        // Maybe the input word IDs are actually 0..15? 
                        // "Word IDs (each 0..255)". 
                        // 
                        // If we must support 0..255 with 16 slots, we need a hash function or direct map.
                        // Let's use direct map: child_idx = word_id[3:0] (lower 4 bits).
                        // This allows 16 distinct children. If collision, we fail or overwrite.
                        // Given the constraints, direct map is the most hardware-friendly interpretation.
                        // We will assume word_id[3:0] determines the slot.
                        
                        // Logic:
                        // child_slot = word_id[3:0]
                        // if trie_child[current_node][child_slot] == 8'hFF:
                        //    trie_child[current_node][child_slot] = next_node_idx
                        //    current_node = next_node_idx
                        //    next_node_idx = next_node_idx + 1
                        // else:
                        //    current_node = trie_child[current_node][child_slot]
                        
                        // We need a temporary register to hold the result of the lookup to update trie in next cycle?
                        // No, we can update in the same cycle if we read the array.
                        // Verilog arrays in always blocks can be read/written.
                        // We need to be careful with write conflicts if we read the same index, but here indices differ.
                        
                        // Implementation in separate combinational block or logic here.
                        // Let's do it here.
                    end else begin
                        // Finished words for this question
                        // Increment count at current_node
                        // Reset current_node to 0 for next question
                        // Increment build_q_idx
                        // Reset build_w_in_q
                    end
                end
            end
        end
    end
    
    // Separate logic for BUILD_TRIE execution to keep things cleaner
    // Since we can't easily do complex loops in one always block without flooding cycles,
    // let's verify the cycle budget.
    // Input: ~50 bytes. DP: T * N nodes. T<=8, N<=32. 256 operations.
    // Total cycles should be fine for 200 limit if we are careful.
    // But building trie might take time.
    // 
    // Let's implement the BUILD_TRIE logic as a sequential process within the main FSM.
    // We'll break it down into micro-states if needed.
    
    // Micro-states for BUILD_TRIE:
    localparam [1:0] BUILD_IDLE = 2'd0;
    localparam [1:0] BUILD_INSERT = 2'd1;
    localparam [1:0] BUILD_FINISH_Q = 2'd2;
    reg [1:0] build_sub_state;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            build_sub_state <= BUILD_IDLE;
        end else begin
            case (build_sub_state)
                BUILD_IDLE: begin
                    if (state == BUILD_TRIE) begin
                        if (build_q_idx < num_questions) begin
                            if (build_w_in_q < question_word_counts[build_q_idx]) begin
                                build_sub_state <= BUILD_INSERT;
                            end else begin
                                build_sub_state <= BUILD_FINISH_Q;
                            end
                        end
                    end
                end
                BUILD_INSERT: begin
                    // Insert logic
                    // Use word_buffer[build_word_idx]
                    // Map to child slot
                    // Update current_node and next_node_idx
                    // This happens in combinational logic triggered by this state
                    build_sub_state <= BUILD_IDLE; // Go back to check next step
                end
                BUILD_FINISH_Q: begin
                    // Increment count at current_node
                    // Reset current_node, update indices
                    build_sub_state <= BUILD_IDLE;
                end
            endcase
        end
    end

    // Combinational Logic for BUILD_TRIE operations
    always @(*) begin
        if (state == BUILD_TRIE && build_sub_state == BUILD_INSERT) begin
            // We are inserting a word
            // Note: This logic might trigger multiple writes to arrays in one cycle which is fine.
            // We need to compute the next values for registers.
            // Since this is combinational, we assume inputs are stable.
            
            // We need to read current_node, word_buffer, trie_child
            // But we need to be careful: reading/writing same array in one block can be tricky in simulation vs synthesis.
            // Usually synthesizable if addresses differ or we are careful.
            // 
            // Let's use a temporary variable for the next state computation.
            // However, we can't assign to regs in combinational block unless we use blocking assignment.
            // And we need to assign to the actual regs for the state to update.
            // 
            // Actually, for micro-state transitions, we update registers in the clocked block.
            // For data updates, we can use continuous assignments or clocked logic.
            // 
            // Let's do data updates in clocked logic triggered by build_sub_state.
            // This is safer.
        end
    end

    // Let's merge the complex logic back into the sequential block but separate the logic gates.
    // To save time and complexity, we will assume a slightly different architecture:
    // We parse and build the trie ON THE FLY during PARSE_Q.
    // We use the 'temp_word_ids' buffer (size 4) to hold the current question's words.
    // When we finish a question (read answer), we insert these words into the trie.
    // This avoids storing a large word buffer.
    // 
    // We need to extend PARSE_Q state to handle insertion after reading answer.
    // We can use a counter to delay transition or add a sub-state.
    // 
    // Let's add a sub-state to PARSE_Q for "INSERTION" phase.
    
    localparam [2:0] PARSE_IDLE   = 3'd0;
    localparam [2:0] P_META       = 3'd1;
    localparam [2:0] P_WAIT_Q     = 3'd2; // Wait for length
    localparam [2:0] P_READ_LEN   = 3'd3;
    localparam [2:0] P_READ_WORDS = 3'd4;
    localparam [2:0] P_READ_ANS   = 3'd5;
    localparam [2:0] P_INSERT     = 3'd6; // New state for insertion
    
    // We will restructure the parsing FSM.
    // Regs for insertion:
    reg [4:0] insert_word_idx; // 0 to word_len-1
    reg [4:0] insert_node;     // Current node during insertion
    reg insert_done_flag;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            parse_phase <= P_IDLE;
            word_len <= 8'd0;
            current_q <= 8'd0;
            insert_word_idx <= 5'd0;
            insert_node <= 5'd0;
        end else begin
            if (state == IDLE && start) begin
                parse_phase <= P_META;
                byte_counter <= 8'd0;
                current_q <= 8'd0;
                total_time <= 8'd0;
                num_questions <= 8'd0;
                insert_node <= 5'd0;
                // Reset trie
                for (i = 0; i < 32; i = i + 1) begin
                    trie_count[i] <= 8'd0;
                    for (j = 0; j < 16; j = j + 1) begin
                        trie_child[i][j] <= 8'hFF;
                    end
                end
                next_node_idx <= 5'd1;
            end
            
            if (state == PARSE_META) begin
                if (data_valid) begin
                    if (byte_counter == 0) total_time <= data_in;
                    else num_questions <= data_in;
                    byte_counter <= byte_counter + 1;
                    if (byte_counter >= 1) parse_phase <= P_WAIT_Q;
                end
            end
            
            if (state == PARSE_Q) begin
                case (parse_phase)
                    P_WAIT_Q: begin
                        // Check if done
                        if (current_q >= num_questions) begin
                            parse_phase <= P_IDLE; // Should transition state
                        end else if (data_valid) begin
                            word_len <= data_in;
                            insert_word_idx <= 5'd0;
                            insert_node <= 5'd0; // Start at root
                            parse_phase <= P_READ_WORDS;
                        end
                    end
                    
                    P_READ_WORDS: begin
                        if (data_valid) begin
                            // Insert this word immediately
                            // We are at insert_node. Word is data_in.
                            // Map word to slot: data_in[3:0]
                            // Check child
                            // We need to use a temporary variable or update in next cycle.
                            // Let's do it in this cycle using combinational logic reading/writing to regs.
                            // 
                            // Note: Writing to an array in the same cycle as reading it is okay if indices are different.
                            // Here we read trie_child[insert_node][slot] and maybe write to it.
                            // If we write, the read value is the old one.
                            
                            // We need to be careful about Verilog array semantics.
                            // It's better to separate read and write.
                            // Let's register the slot index and action.
                            
                            // But we have the constraint of synthesizability and Icarus compatibility.
                            // 
                            // Let's simplify: Insert logic takes 1 cycle per word.
                            // We will calculate the next node in combinational logic based on current state.
                            // 
                            // Since we can't easily do logic inside the case without blocking, 
                            // let's assume we do it in the combinational block driving the next state of 'insert_node' and 'next_node_idx'.
                            // 
                            // We will create a combinational block for the trie insertion logic.
                        end
                    end
                    
                    P_READ_ANS: begin
                        if (data_valid) begin
                            // Answer ID ignored, but we increment question count at current node
                            // We need to increment trie_count[insert_node]
                            trie_count[insert_node] <= trie_count[insert_node] + 8'd1;
                            
                            current_q <= current_q + 8'd1;
                            if (current_q + 8'd1 >= num_questions) begin
                                parse_phase <= P_IDLE; // Done parsing
                            end else begin
                                parse_phase <= P_WAIT_Q;
                            end
                        end
                    end
                endcase
            end
        end
    end

    // Combinational Trie Insertion Logic
    // This block computes the values for insert_node, next_node_idx, and trie_child updates
    // based on the current parse phase and input data.
    // It is triggered whenever inputs or state change.
    
    reg [3:0] slot;
    reg [7:0] child_node;
    reg [4:0] next_node_free;
    reg [4:0] current_insert_node_reg;
    
    always @(*) begin
        slot = 4'd0;
        child_node = 8'hFF;
        next_node_free = next_node_idx;
        current_insert_node_reg = insert_node;
        
        if (state == PARSE_Q && parse_phase == P_READ_WORDS && data_valid) begin
            slot = data_in[3:0];
            child_node = trie_child[insert_node][slot];
            
            if (child_node == 8'hFF) begin
                // Allocate new node
                // The update will happen in the clocked block
                // We need to signal that we should update.
                // In Verilog, we can't directly assign to regs in comb block.
                // So we rely on the clocked block to detect this condition.
            end
        end
    end

    // We need to separate the logic: The clocked block decides WHEN to update.
    // The combinational block computes WHAT to update.
    // But since we are in a sequential design, let's keep the insertion logic inside the clocked block
    // but separate it by a cycle if needed. 
    // Given the "1 cycle per word" requirement and 200 cycle budget, we can afford 1 cycle per word.
    // We just need to make sure we don't have read-after-write hazards.
    // 
    // Let's use a temporary register to store the result of the lookup for the NEXT cycle.
    // But that would double the cycles.
    // 
    // We will stick to the on-the-fly insertion in the clocked block.
    // We will read the array, compute the new value, and write it back.
    // This is standard for FPGA BRAMs (read-during-write might be undefined or old data, which is fine).
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // handled above
        end else begin
            if (state == PARSE_Q && parse_phase == P_READ_WORDS && data_valid) begin
                // Insert word data_in
                // 1. Determine slot
                slot = data_in[3:0];
                // 2. Check if child exists
                if (trie_child[insert_node][slot] == 8'hFF) begin
                    // Create new node
                    trie_child[insert_node][slot] <= next_node_idx;
                    insert_node <= next_node_idx;
                    next_node_idx <= next_node_idx + 5'd1;
                end else begin
                    // Move to existing node
                    insert_node <= trie_child[insert_node][slot];
                end
                
                // Increment word counter
                insert_word_idx <= insert_word_idx + 5'd1;
                
                // Check if this was the last word
                // Note: word_len is from P_WAIT_Q state
                if (insert_word_idx + 5'd1 >= word_len) begin
                    parse_phase <= P_READ_ANS;
                end
            end
        end
    end

    // DP Computation Iterator Logic (Updated)
    // We need to handle the case where num_questions == 0.
    // In that case, trie_count[0] = 0.
    // DP[tau][0] = 0.
    // Result = 0.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // handled
        end else begin
            if (state == BUILD_TRIE) begin
                // Check if num_questions is 0
                if (num_questions == 0) begin
                    // We can skip directly to DP computation logic (which will do nothing)
                    // or just transition. 
                    // But we need to set result to 0.
                end
            end
            
            if (state == DP_COMPUTE) begin
                // Perform DP update for (tau, node_iter)
                k = trie_count[node_iter];
                
                if (k > 0) begin
                    // Score Answer
                    root_dp_prev = dp_table[5'd0][tau - 8'd1];
                    if (k <= 8) score_answer = inv_k_table[k] + root_dp_prev;
                    else score_answer = root_dp_prev;
                    
                    // Score Wait
                    sum_wait = 16'd0;
                    for (j = 0; j < 16; j = j + 1) begin
                        if (trie_child[node_iter][j] != 8'hFF) begin
                            prob_numer = trie_count[trie_child[node_iter][j]];
                            dp_child = dp_table[trie_child[node_iter][j]][tau - 8'd1];
                            
                            // (prob_numer * dp_child) / k
                            // We need to be careful with precision.
                            // Let's use 32-bit intermediate.
                            mult_result = (prob_numer * dp_child) >> 8; // / 256
                            
                            // Divide by k
                            if (k == 1) mult_result = mult_result;
                            else if (k == 2) mult_result = mult_result >> 1;
                            else if (k == 3) mult_result = (mult_result * 85) >> 8;
                            else if (k == 4) mult_result = mult_result >> 2;
                            else if (k == 5) mult_result = (mult_result * 51) >> 8;
                            else if (k == 6) mult_result = (mult_result * 43) >> 8;
                            else if (k == 7) mult_result = (mult_result * 37) >> 8;
                            else if (k == 8) mult_result = mult_result >> 3;
                            else mult_result = mult_result / k;
                            
                            sum_wait = sum_wait + mult_result;
                        end
                    end
                    score_wait = sum_wait;
                    
                    if (score_answer > score_wait) dp_table[node_iter][tau] <= score_answer;
                    else dp_table[node_iter][tau] <= score_wait;
                end
            end
            
            if (state == DP_FINAL) begin
                result <= dp_table[5'd0][total_time];
            end
        end
    end
    
    // Handle State Transitions for PARSE_Q completion
    always @(*) begin
        // Logic for transitioning out of PARSE_Q
        // If we are in P_IDLE (which means parsing is done), go to BUILD_TRIE
        if (state == PARSE_Q && parse_phase == P_IDLE) next_state = BUILD_TRIE;
    end

endmodule