module word_guess_solver (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    input [127:0] hidden_pattern,
    input [4:0] m,
    input [127:0] word_list [0:15],
    output reg [3:0] result_count,
    output reg done
);

    // State definitions
    localparam IDLE    = 3'b000;
    localparam LOAD    = 3'b001;
    localparam FILTER  = 3'b010;
    localparam INTERSECT = 3'b011;
    localparam DONE    = 3'b100;

    // Internal Registers
    reg [2:0] state;
    reg [4:0] char_idx;          // Generic character index counter
    reg [4:0] word_idx;          // Word index counter (for FILTER state)
    reg [4:0] valid_idx;         // Index for valid words (for INTERSECT state)
    reg [4:0] n_reg;             // Registered n
    reg [4:0] m_reg;             // Registered m
    reg [127:0] pat_reg;         // Registered hidden pattern
    
    // Maps and Storage
    reg [255:0] revealed_map;    // 1 byte per char, 256 bits for ASCII range
    reg [127:0] candidates [0:15]; // Storage for valid words
    reg [255:0] intersection_map; // Intersection of letters
    reg [255:0] temp_map;        // Temporary map for current word
    
    // Counters
    reg [3:0] valid_count;       // Number of valid words found
    reg [3:0] bit_count_idx;     // Index for counting bits in DONE state
    
    // Helper logic for current word/char access in FILTER state
    wire [7:0] current_char;
    wire [7:0] pattern_char;
    // Note: We read current word from 'candidates' or 'word_list' depending on state.
    // For FILTER state, we need to access word_list[word_idx]
    // For INTERSECT state, we access candidates[valid_idx]
    
    // Combinatorial selection of current character for comparison
    reg [127:0] active_word;
    always @(*) begin
        if (state == FILTER) begin
            active_word = word_list[word_idx];
        end else if (state == INTERSECT) begin
            active_word = candidates[valid_idx];
        end else begin
            active_word = 0;
        end
    end
    
    assign current_char = active_word[char_idx*8 +: 8];
    assign pattern_char = pat_reg[char_idx*8 +: 8];

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (start) state <= LOAD;
                end
                
                LOAD: begin
                    // Build revealed_map
                    if (char_idx == n_reg && n_reg != 0) begin
                        state <= FILTER;
                    end else if (n_reg == 0) begin
                        state <= FILTER;
                    end
                end
                
                FILTER: begin
                    // Process words. If we finished checking all words, go to INTERSECT
                    // Logic handles char_idx iteration internally
                    if (word_idx == m_reg) begin
                        state <= INTERSECT;
                    end
                end
                
                INTERSECT: begin
                    // Process valid words. If finished, go to DONE
                    if (valid_idx == valid_count) begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    // Wait for start to go low to return to IDLE
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            done <= 0;
            result_count <= 0;
            char_idx <= 0;
            word_idx <= 0;
            valid_idx <= 0;
            valid_count <= 0;
            bit_count_idx <= 0;
            revealed_map <= 0;
            intersection_map <= 0;
            temp_map <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Register inputs
                        n_reg <= n;
                        m_reg <= m;
                        pat_reg <= hidden_pattern;
                        
                        // Reset counters
                        char_idx <= 0;
                        word_idx <= 0;
                        valid_idx <= 0;
                        valid_count <= 0;
                        bit_count_idx <= 0;
                        done <= 0;
                        result_count <= 0;
                        revealed_map <= 0;
                        intersection_map <= 0;
                    end
                end

                LOAD: begin
                    // Build revealed_map based on hidden_pattern
                    // Iterate char_idx 0 to n-1
                    if (char_idx < n_reg) begin
                        // Check if character is not '*' (8'h2A)
                        if (pat_reg[char_idx*8 +: 8] != 8'h2A) begin
                            // Set bit in revealed_map corresponding to the ASCII value
                            revealed_map[pat_reg[char_idx*8 +: 8]] <= 1'b1;
                        end
                        char_idx <= char_idx + 1;
                    end
                end

                FILTER: begin
                    // Logic: Check word 'word_idx' for validity
                    // We iterate 'char_idx' 0 to n-1 for the current word
                    
                    if (word_idx < m_reg) begin
                        
                        if (char_idx == 0) begin
                            // Start of new word: Reset temporary validity check flags
                            // We'll use 'intersection_map' temporarily as a 'validity flag' for this word?
                            // No, let's use 'temp_map' to store valid/invalid status for the word.
                            // Actually, just a single bit register is enough.
                            // Let's use 'valid_count' register to store 'is_current_word_valid' temporarily? No.
                            // Let's use a separate flag logic or just compute validity.
                            // To keep it simple, we will use 'intersection_map' register to track 'current_word_valid'.
                            // If we set intersection_map[0] = 1, it means valid.
                            // Better: Use a local register `current_word_is_valid`.
                        end
                        
                        // NOTE: The logic inside FILTER is complex to fit in one cycle per word.
                        // We need a state machine inside the state (implicit by char_idx control).
                        // We need to check validity over n cycles.
                        
                        // Let's refine: We need to determine validity of the word.
                        // We can use 'valid_idx' to track 'is_current_word_valid' (as a boolean flag, though it's 4 bits).
                        // Let's use `valid_idx` as boolean: 1=valid, 0=invalid. (Reset to 1 at start of word).
                        
                        if (char_idx == 0) valid_idx <= 1; // Assume valid initially
                        
                        // Check character at char_idx
                        if (valid_idx == 1) begin // Only check if still valid
                            // Rule 1: Revealed positions match exactly
                            if (pattern_char != 8'h2A && pattern_char != current_char) begin
                                valid_idx <= 0;
                            end
                            // Rule 2: Unknown positions dont contain revealed letters
                            else if (pattern_char == 8'h2A) begin
                                if (revealed_map[current_char]) begin
                                    valid_idx <= 0;
                                end
                            end
                        end
                        
                        // Move to next char
                        if (char_idx < n_reg - 1) begin
                            char_idx <= char_idx + 1;
                        end else begin
                            // End of word
                            // 'valid_idx' now holds validity (1 or 0)
                            if (valid_idx == 1) begin
                                // Store word in candidates array
                                candidates[valid_count] <= word_list[word_idx];
                                valid_count <= valid_count + 1;
                            end
                            
                            // Move to next word
                            word_idx <= word_idx + 1;
                            char_idx <= 0;
                        end
                    end
                end

                INTERSECT: begin
                    // Process valid words stored in candidates
                    // valid_count is total valid words
                    // valid_idx is current index being processed
                    
                    if (valid_idx < valid_count) begin
                        
                        // Build temp_map for current valid word
                        if (char_idx == 0) begin
                            // Reset temp_map at start of word processing
                            temp_map <= 0;
                        end
                        
                        // Read char from candidates[valid_idx] at position char_idx
                        // Check if hidden_pattern at this position is unknown ('*')
                        if (pat_reg[char_idx*8 +: 8] == 8'h2A) begin
                            // It is an unknown position, we care about this letter
                            temp_map[candidates[valid_idx][char_idx*8 +: 8]] <= 1'b1;
                        end
                        
                        if (char_idx < n_reg - 1) begin
                            char_idx <= char_idx + 1;
                        end else begin
                            // End of word: Update intersection_map
                            // Logic: 
                            // If this is the FIRST valid word (valid_idx == 0): intersection = temp_map
                            // Else: intersection = intersection & temp_map
                            
                            if (valid_idx == 0) begin
                                intersection_map <= temp_map;
                            end else begin
                                intersection_map <= intersection_map & temp_map;
                            end
                            
                            // Next valid word
                            valid_idx <= valid_idx + 1;
                            char_idx <= 0;
                        end
                    end
                end

                DONE: begin
                    // Calculate result_count from intersection_map
                    // We sum 16 bits per cycle to be efficient
                    // bit_count_idx goes from 0 to 15
                    
                    if (bit_count_idx < 16) begin
                        // Sum 16 bits explicitly (Verilog synthesis will create adder tree or sequential adder)
                        // We split into chunks to keep logic depth low
                        result_count <= result_count + 
                                       intersection_map[bit_count_idx*16 + 0] + 
                                       intersection_map[bit_count_idx*16 + 1] + 
                                       intersection_map[bit_count_idx*16 + 2] + 
                                       intersection_map[bit_count_idx*16 + 3] + 
                                       intersection_map[bit_count_idx*16 + 4] + 
                                       intersection_map[bit_count_idx*16 + 5] + 
                                       intersection_map[bit_count_idx*16 + 6] + 
                                       intersection_map[bit_count_idx*16 + 7] + 
                                       intersection_map[bit_count_idx*16 + 8] + 
                                       intersection_map[bit_count_idx*16 + 9] + 
                                       intersection_map[bit_count_idx*16 + 10] + 
                                       intersection_map[bit_count_idx*16 + 11] + 
                                       intersection_map[bit_count_idx*16 + 12] + 
                                       intersection_map[bit_count_idx*16 + 13] + 
                                       intersection_map[bit_count_idx*16 + 14] + 
                                       intersection_map[bit_count_idx*16 + 15];
                        bit_count_idx <= bit_count_idx + 1;
                    end else begin
                        // Final result is ready
                        done <= 1;
                    end
                end
            endcase
        end
    end

endmodule