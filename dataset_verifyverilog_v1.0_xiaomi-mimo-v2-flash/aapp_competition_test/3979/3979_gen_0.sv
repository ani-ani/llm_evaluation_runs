module CapitalizationEngine (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_words,
    input wire [3:0] word_lens [0:15],
    input wire [7:0] words_flat [0:255],
    input wire [3:0] num_letters,
    output reg result_valid,
    output reg [15:0] result_mask,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE    = 4'd0;
    localparam [3:0] PARSE   = 4'd1;
    localparam [3:0] COMPARE = 4'd2;
    localparam [3:0] IMPLY   = 4'd3;
    localparam [4:0] VERIFY  = 4'd4;
    localparam [4:0] CONFLICT = 4'd5;
    localparam [4:0] DONE    = 4'd6;

    reg [3:0] state;
    reg [3:0] next_state;

    // Control variables
    reg [3:0] word_idx;           // Current word pair index (0 to n_words-2)
    reg [3:0] char_idx;           // Current character index in word
    reg [3:0] parse_word_idx;     // For parsing phase
    reg [3:0] parse_char_idx;     // For parsing phase
    reg [3:0] pair_idx;           // Word pair being compared
    reg [3:0] letter_idx;         // For 2-SAT verification

    // Storage for parsed words
    reg [7:0] parsed_words [0:15][0:15];  // 16 words x 16 chars
    reg [3:0] parsed_lens [0:15];         // Parsed lengths
    reg [3:0] num_words_stored;

    // 2-SAT variables (16 letters => 16*2 = 32 variables)
    // Variable 2*i = letter i NOT capitalized (false)
    // Variable 2*i+1 = letter i capitalized (true)
    // Graph: adjacency list for implication graph
    // Forward edges: imp_graph[u][v] = 1 means u -> v
    reg imp_graph [0:31][0:31];
    reg implication_done;

    // For cycle counter to prevent infinite loops
    reg [8:0] cycle_count;
    localparam [8:0] MAX_CYCLES = 9'd512;

    // Temp storage for comparisons
    reg [7:0] char1;
    reg [7:0] char2;
    reg [3:0] compare_len1;
    reg [3:0] compare_len2;

    // Variables for building implications
    reg [3:0] letter_a;
    reg [3:0] letter_b;

    // BFS/DFS variables for implication check
    reg visited [0:31];
    reg [4:0] queue [0:63];
    reg [5:0] queue_head;
    reg [5:0] queue_tail;
    reg conflict_found;

    // Helper tasks for 2-SAT
    task add_implication;
        input [4:0] u;
        input [4:0] v;
        begin
            imp_graph[u][v] = 1'b1;
        end
    endtask

    task clear_graph;
        integer i, j;
        begin
            for (i = 0; i < 32; i = i + 1) begin
                for (j = 0; j < 32; j = j + 1) begin
                    imp_graph[i][j] = 1'b0;
                end
            end
        end
    endtask

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            result_mask <= 16'd0;
            done <= 1'b0;
            word_idx <= 4'd0;
            char_idx <= 4'd0;
            parse_word_idx <= 4'd0;
            parse_char_idx <= 4'd0;
            pair_idx <= 4'd0;
            letter_idx <= 4'd0;
            num_words_stored <= 4'd0;
            implication_done <= 1'b0;
            cycle_count <= 9'd0;
            clear_graph();
            // Initialize parsed_words
            for (int i = 0; i < 16; i = i + 1) begin
                for (int j = 0; j < 16; j = j + 1) begin
                    parsed_words[i][j] <= 8'd0;
                end
                parsed_lens[i] <= 4'd0;
            end
        end else begin
            cycle_count <= cycle_count + 9'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    result_mask <= 16'd0;
                    word_idx <= 4'd0;
                    char_idx <= 4'd0;
                    parse_word_idx <= 4'd0;
                    parse_char_idx <= 4'd0;
                    pair_idx <= 4'd0;
                    letter_idx <= 4'd0;
                    implication_done <= 1'b0;
                    cycle_count <= 9'd0;
                    clear_graph();
                    
                    if (start && n_words > 4'd0) begin
                        state <= PARSE;
                        num_words_stored <= n_words;
                    end
                end

                PARSE: begin
                    // Parse words from flattened array
                    // Each word has word_lens[parse_word_idx] characters
                    // words_flat index calculation: sum of previous word lengths + parse_char_idx
                    begin : parse_block
                        integer i;
                        integer flat_idx;
                        flat_idx = 0;
                        for (i = 0; i < parse_word_idx; i = i + 1) begin
                            flat_idx = flat_idx + word_lens[i];
                        end
                        flat_idx = flat_idx + parse_char_idx;
                        parsed_words[parse_word_idx][parse_char_idx] <= words_flat[flat_idx];
                    end
                    
                    if (parse_char_idx < word_lens[parse_word_idx] - 4'd1) begin
                        parse_char_idx <= parse_char_idx + 4'd1;
                    end else begin
                        parsed_lens[parse_word_idx] <= word_lens[parse_word_idx];
                        parse_char_idx <= 4'd0;
                        if (parse_word_idx < n_words - 4'd1) begin
                            parse_word_idx <= parse_word_idx + 4'd1;
                        end else begin
                            parse_word_idx <= 4'd0;
                            parse_char_idx <= 4'd0;
                            pair_idx <= 4'd0;
                            state <= COMPARE;
                        end
                    end
                end

                COMPARE: begin
                    // Compare word pair_idx and pair_idx+1
                    // Find first differing position
                    char1 <= parsed_words[pair_idx][char_idx];
                    char2 <= parsed_words[pair_idx + 4'd1][char_idx];
                    compare_len1 <= parsed_lens[pair_idx];
                    compare_len2 <= parsed_lens[pair_idx + 4'd1];
                    
                    if (char_idx < compare_len1 && char_idx < compare_len2) begin
                        if (char1 != char2) begin
                            // Found differing character
                            if (char1 < char2) begin
                                // Constraint: if char2 capitalized, char1 must also be capitalized
                                // letter_a = char2, letter_b = char1
                                letter_a <= char1[3:0];
                                letter_b <= char2[3:0];
                                // Implications:
                                // NOT char2 -> NOT char1 (char2 capitalized => char1 capitalized)
                                // char1 -> char2 (char1 not capitalized => char2 not capitalized)
                                add_implication({1'b0, char1[3:0]}, {1'b0, char2[3:0]});
                                add_implication({1'b1, char2[3:0]}, {1'b1, char1[3:0]});
                            end else begin // char1 > char2
                                // Must capitalize char1, NOT capitalize char2
                                // char1 capitalized, char2 not capitalized
                                letter_a <= char1[3:0];
                                letter_b <= char2[3:0];
                                add_implication({1'b0, char1[3:0]}, {1'b1, char2[3:0]});
                                add_implication({1'b1, char2[3:0]}, {1'b0, char1[3:0]});
                                // Force assignments for this pair
                                // char1 must be capitalized
                                add_implication({1'b0, char1[3:0]}, {1'b1, char1[3:0]});
                                // char2 must NOT be capitalized
                                add_implication({1'b1, char2[3:0]}, {1'b0, char2[3:0]});
                            end
                            char_idx <= 4'd0;
                            if (pair_idx < n_words - 4'd2) begin
                                pair_idx <= pair_idx + 4'd1;
                                state <= COMPARE;
                            end else begin
                                state <= IMPLY;
                            end
                        end else begin
                            // Characters equal, check next
                            char_idx <= char_idx + 4'd1;
                            state <= COMPARE;
                        end
                    end else begin
                        // One word is prefix of another or lengths differ
                        // OK only if prefix word is not longer
                        if (compare_len1 > compare_len2) begin
                            // Invalid: longer word is prefix of shorter
                            state <= CONFLICT;
                        end else begin
                            char_idx <= 4'd0;
                            if (pair_idx < n_words - 4'd2) begin
                                pair_idx <= pair_idx + 4'd1;
                                state <= COMPARE;
                            end else begin
                                state <= IMPLY;
                            end
                        end
                    end
                end

                IMPLY: begin
                    // Use BFS to propagate implications
                    // For each letter, check both assignments
                    // We'll check all variables in the graph
                    implication_done <= 1'b0;
                    conflict_found <= 1'b0;
                    letter_idx <= 4'd0;
                    state <= VERIFY;
                end

                VERIFY: begin
                    // BFS from each forced assignment to find conflicts
                    // Check if we have both forced "not capital" and "capital" for same letter
                    // Initialize visited
                    for (int i = 0; i < 32; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    queue_head <= 6'd0;
                    queue_tail <= 6'd0;

                    // Check for forced assignments and start BFS
                    // We check each variable that is forced
                    if (letter_idx < num_letters) begin
                        // Check if letter forced to NOT capitalize (0)
                        // Check if letter forced to capitalize (1)
                        // Use global implication checking
                        begin : verify_block
                            integer i, j, k;
                            reg [4:0] start_node;
                            reg [4:0] node;
                            reg [4:0] next_node;
                            
                            // Check implication from NOT capitalized (2*idx) to capitalized (2*idx+1)
                            // If both paths exist, conflict
                            for (k = 0; k < num_letters; k = k + 1) begin
                                // Check 2*k -> 2*k+1 path
                                if (check_implication(2*k, 2*k+1)) begin
                                    conflict_found <= 1'b1;
                                end
                                // Check 2*k+1 -> 2*k path
                                if (check_implication(2*k+1, 2*k)) begin
                                    conflict_found <= 1'b1;
                                end
                            end
                        end
                        letter_idx <= letter_idx + 4'd1;
                        state <= VERIFY;
                    end else begin
                        // Done checking all letters
                        if (conflict_found) begin
                            state <= CONFLICT;
                        end else begin
                            state <= DONE;
                        end
                    end
                end

                CONFLICT: begin
                    result_valid <= 1'b1;
                    result_mask <= 16'd0;  // No valid assignment
                    done <= 1'b1;
                    state <= IDLE;
                end

                DONE: begin
                    // Extract result: for each letter, check if forced to capitalize
                    result_mask <= 16'd0;
                    for (int i = 0; i < num_letters; i = i + 1) begin
                        // Check if implication forces capitalization
                        // If NOT capitalized -> capitalized path exists (forced)
                        if (imp_graph[2*i][2*i+1]) begin
                            result_mask[i] <= 1'b1;
                        end else if (imp_graph[2*i+1][2*i]) begin
                            result_mask[i] <= 1'b0;
                        end else begin
                            // No constraint, default to NOT capitalized
                            result_mask[i] <= 1'b0;
                        end
                    end
                    result_valid <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            // Timeout check
            if (cycle_count >= MAX_CYCLES) begin
                state <= CONFLICT;
            end
        end
    end

    // Helper function to check implication path using BFS
    function automatic check_implication;
        input [4:0] start;
        input [4:0] target;
        reg visited_reg [0:31];
        reg [4:0] queue_reg [0:63];
        reg [5:0] head_reg;
        reg [5:0] tail_reg;
        reg [4:0] curr;
        reg [4:0] neighbor;
        integer i;
        begin
            // Initialize
            for (i = 0; i < 32; i = i + 1) begin
                visited_reg[i] = 1'b0;
            end
            head_reg = 6'd0;
            tail_reg = 6'd0;
            
            // Start BFS
            queue_reg[tail_reg] = start;
            tail_reg = tail_reg + 6'd1;
            visited_reg[start] = 1'b1;
            
            while (head_reg != tail_reg) begin
                curr = queue_reg[head_reg];
                head_reg = head_reg + 6'd1;
                
                if (curr == target) begin
                    check_implication = 1'b1;
                    return;
                end
                
                // Check all neighbors
                for (i = 0; i < 32; i = i + 1) begin
                    if (imp_graph[curr][i] && !visited_reg[i]) begin
                        queue_reg[tail_reg] = i[4:0];
                        tail_reg = tail_reg + 6'd1;
                        visited_reg[i] = 1'b1;
                    end
                end
            end
            
            check_implication = 1'b0;
        end
    endfunction

endmodule