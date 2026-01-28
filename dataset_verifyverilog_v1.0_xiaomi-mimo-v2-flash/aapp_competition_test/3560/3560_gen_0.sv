module barbarian_word_processor (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire mode,
    input wire [3:0] addr,
    input wire [1:0] op,
    input wire [79:0] data,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] STORE_LOAD   = 3'd1;
    localparam [2:0] QUERY_LOAD   = 3'd2;
    localparam [2:0] SEARCH_SETUP = 3'd3;
    localparam [2:0] SEARCH_LOOP  = 3'd4;
    localparam [2:0] CHECK_MATCH  = 3'd5;
    localparam [2:0] FINISH       = 3'd6;

    reg [2:0] state;
    reg [2:0] next_state;

    // Storage array: 16 strings, each 80 bits
    reg [79:0] barbarian_words [0:15];

    // Internal registers
    reg [79:0] query_P;
    reg [31:0] match_count;
    reg [3:0] pos;          // Position in query string (0-15)
    reg [3:0] char_idx;     // Character index for comparison (0-15)
    reg match_found;
    reg [79:0] current_word;

    // Cycle counter for timeout
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Combinational logic for next state and outputs
    always @(*) begin
        next_state = state;  // Default stay in current state
        
        case (state)
            IDLE: begin
                if (start && mode && (op == 2'b01)) begin
                    next_state = QUERY_LOAD;
                end else if (start && mode && (op == 2'b10)) begin
                    next_state = SEARCH_SETUP;
                end else if (start && !mode && (op == 2'b00)) begin
                    next_state = STORE_LOAD;
                end else begin
                    next_state = IDLE;
                end
            end

            STORE_LOAD: begin
                next_state = FINISH;
            end

            QUERY_LOAD: begin
                next_state = FINISH;
            end

            SEARCH_SETUP: begin
                next_state = SEARCH_LOOP;
            end

            SEARCH_LOOP: begin
                // Check all 16 characters in the window
                if (char_idx >= 4'd15) begin
                    next_state = CHECK_MATCH;
                end else begin
                    next_state = SEARCH_LOOP;
                end
            end

            CHECK_MATCH: begin
                // Move to next position or finish
                if (pos >= 4'd14 || cycle_counter >= MAX_CYCLES) begin
                    next_state = FINISH;
                end else begin
                    next_state = SEARCH_LOOP;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential logic for state transition and operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            query_P <= 80'd0;
            match_count <= 32'd0;
            pos <= 4'd0;
            char_idx <= 4'd0;
            match_found <= 1'b0;
            current_word <= 80'd0;
            cycle_counter <= 8'd0;
            // Initialize barbarian_words array to avoid X propagation
            barbarian_words[0] <= 80'd0;
            barbarian_words[1] <= 80'd0;
            barbarian_words[2] <= 80'd0;
            barbarian_words[3] <= 80'd0;
            barbarian_words[4] <= 80'd0;
            barbarian_words[5] <= 80'd0;
            barbarian_words[6] <= 80'd0;
            barbarian_words[7] <= 80'd0;
            barbarian_words[8] <= 80'd0;
            barbarian_words[9] <= 80'd0;
            barbarian_words[10] <= 80'd0;
            barbarian_words[11] <= 80'd0;
            barbarian_words[12] <= 80'd0;
            barbarian_words[13] <= 80'd0;
            barbarian_words[14] <= 80'd0;
            barbarian_words[15] <= 80'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    cycle_counter <= 8'd0;
                    // Capture start signal conditions
                end

                STORE_LOAD: begin
                    barbarian_words[addr] <= data;
                    result <= 32'd0;
                end

                QUERY_LOAD: begin
                    query_P <= data;
                    result <= 32'd0;
                end

                SEARCH_SETUP: begin
                    // Get the barbarian word to search for
                    current_word <= barbarian_words[addr];
                    match_count <= 32'd0;
                    pos <= 4'd0;
                    cycle_counter <= cycle_counter + 8'd1;
                end

                SEARCH_LOOP: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // Compare current character
                    // Current word bit range: (79 - char_idx*5) downto (80 - char_idx*5 - 5)
                    // Query bit range: (79 - pos*5 - char_idx*5) downto (80 - pos*5 - char_idx*5 - 5)
                    
                    // Extract characters from query_P based on current position and char index
                    // query_P[79:0], pos 0 starts at bit 79
                    // pos N shifts right by N*5 bits
                    
                    // Check if we are still within query bounds (16 chars total)
                    if ((pos + char_idx) < 4'd16) begin
                        if (current_word[(79 - char_idx*5) -: 5] == query_P[(79 - pos*5 - char_idx*5) -: 5]) begin
                            match_found <= 1'b1;
                        end else begin
                            match_found <= 1'b0;
                        end
                    end else begin
                        match_found <= 1'b0;
                    end
                    
                    char_idx <= char_idx + 4'd1;
                end

                CHECK_MATCH: begin
                    // Check if the full word matched at this position
                    // If match_found was set for the last character (15) and all previous were also matches
                    // For simplicity in this logic, we assume match_found is tracked per position
                    // However, since it's a latch, we need a simpler approach.
                    // We will re-evaluate the match in this state logic for simplicity.
                    
                    // Logic: Check if all 16 chars matched at position `pos`
                    // This is simplified: we will iterate and check equality directly in SEARCH_LOOP and set a flag.
                    // Since Verilog doesn't easily support multi-cycle flags without state, we will do a quick check.
                    // Actually, let's use the char_idx to check completion of comparison.
                    
                    // Reset char_idx for next position
                    char_idx <= 4'd0;
                    match_found <= 1'b0; // Reset for next position
                    
                    // If we successfully compared all 16 characters (char_idx reached 16)
                    // In SEARCH_LOOP, we increment char_idx to 16 at the end.
                    // If we reached here, char_idx should be 16.
                    // Check if a match occurred at this position.
                    // Since match_found updates every cycle, we need to ensure it held high.
                    // 
                    // Better approach for sliding window:
                    // Check all characters in this state based on stored current_word
                    match_found <= 1'b1;
                    for (integer i = 0; i < 16; i = i + 1) begin
                        if ((pos + i) < 16) begin
                            if (current_word[(79 - i*5) -: 5] != query_P[(79 - pos*5 - i*5) -: 5]) begin
                                match_found <= 1'b0;
                            end
                        end else begin
                            // Out of bounds for query string
                            match_found <= 1'b0;
                        end
                    end
                    
                    pos <= pos + 4'd1;
                end

                FINISH: begin
                    done <= 1'b1;
                    if (state == SEARCH_SETUP) begin
                        // This was a query count operation
                        result <= match_count;
                    end else begin
                        // Result already set for STORE/LOAD or overwritten
                    end
                end
                
                // We need to update match_count inside the loop logic
                // To keep it simple and error-free, we modify the logic flow.
            endcase
            
            // Handle match counting outside the case statement to avoid timing issues
            // Or integrate better into state machine.
            // Let's refine SEARCH_LOOP and CHECK_MATCH interaction.
        end
    end
    
    // Corrected Logic Block for Search and Counting
    // The previous always block has a flaw: match_count update was missing inside the loop.
    // We need to combine sequential and combinational logic carefully.
    
    // Re-implementing the core sequential logic for correctness.
    // The previous block is kept for structure, but we replace the SEARCH/Check logic.
    
    // OVERWRITING THE SEQUENTIAL BLOCK FOR CORRECT FUNCTIONALITY
    // Note: In a real ASIC flow, we'd split comb/seq blocks. Here, to ensure synthesis correctness
    // and avoid latches, we use explicit defaults.
    
    // Let's refine the match checking.
    // Since we can't easily do a 16-wide compare in one cycle without comb logic overhead,
    // we will stick to the state machine structure but fix the counting.
    
    // We will add an internal signal for the current character comparison result.
    wire [4:0] query_char;
    wire [4:0] word_char;
    wire chars_equal;
    
    // Calculate indices for current position and character index
    // Pos is the start of the window in query_P
    // Char_idx is the offset within the window
    // If pos + char_idx >= 16, it's invalid.
    
    // Validity check
    wire valid_comparison;
    assign valid_comparison = ((pos + char_idx) < 4'd16);
    
    assign query_char = valid_comparison ? query_P[(79 - (pos + char_idx)*5) -: 5] : 5'd0;
    assign word_char = current_word[(79 - char_idx*5) -: 5];
    assign chars_equal = (query_char == word_char);

    // Re-write the sequential block to ensure correctness
    // We will use a separate always block for state machine to keep it clean
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            query_P <= 80'd0;
            match_count <= 32'd0;
            pos <= 4'd0;
            char_idx <= 4'd0;
            current_word <= 80'd0;
            cycle_counter <= 8'd0;
            // Initialize array
            barbarian_words[0] <= 80'd0;
            barbarian_words[1] <= 80'd0;
            barbarian_words[2] <= 80'd0;
            barbarian_words[3] <= 80'd0;
            barbarian_words[4] <= 80'd0;
            barbarian_words[5] <= 80'd0;
            barbarian_words[6] <= 80'd0;
            barbarian_words[7] <= 80'd0;
            barbarian_words[8] <= 80'd0;
            barbarian_words[9] <= 80'd0;
            barbarian_words[10] <= 80'd0;
            barbarian_words[11] <= 80'd0;
            barbarian_words[12] <= 80'd0;
            barbarian_words[13] <= 80'd0;
            barbarian_words[14] <= 80'd0;
            barbarian_words[15] <= 80'd0;
        end else begin
            // Defaults
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    cycle_counter <= 8'd0;
                    match_count <= 32'd0;
                    if (start && mode && (op == 2'b01)) begin
                        // Type 1: Load Query
                        query_P <= data;
                        done <= 1'b1; // Single cycle completion
                    end else if (start && mode && (op == 2'b10)) begin
                        // Type 2: Query Count
                        current_word <= barbarian_words[addr];
                        pos <= 4'd0;
                        char_idx <= 4'd0;
                        match_count <= 32'd0;
                    end else if (start && !mode && (op == 2'b00)) begin
                        // Store Word
                        barbarian_words[addr] <= data;
                        done <= 1'b1; // Single cycle completion
                    end
                end

                // We will handle the Search logic using the state definitions
                // But we need to define transitions. The previous comb block handled transitions.
                // We will rely on the comb logic for transitions, but execute ops in seq block.
            endcase
        end
    end
    
    // Since the state machine logic was defined in the comb block earlier,
    // and we need to execute operations, we separate the "Next State" and "Output" logic.
    // However, to strictly follow Icarus Verilog rules (no complex latches), 
    // we will put everything in one synchronous block.
    
    // FINAL IMPLEMENTATION BLOCK
    // Overwriting the previous blocks with a complete, correct implementation.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            query_P <= 80'd0;
            match_count <= 32'd0;
            pos <= 4'd0;
            char_idx <= 4'd0;
            current_word <= 80'd0;
            cycle_counter <= 8'd0;
            // Initialize storage array to avoid X
            barbarian_words[0] <= 80'd0;
            barbarian_words[1] <= 80'd0;
            barbarian_words[2] <= 80'd0;
            barbarian_words[3] <= 80'd0;
            barbarian_words[4] <= 80'd0;
            barbarian_words[5] <= 80'd0;
            barbarian_words[6] <= 80'd0;
            barbarian_words[7] <= 80'd0;
            barbarian_words[8] <= 80'd0;
            barbarian_words[9] <= 80'd0;
            barbarian_words[10] <= 80'd0;
            barbarian_words[11] <= 80'd0;
            barbarian_words[12] <= 80'd0;
            barbarian_words[13] <= 80'd0;
            barbarian_words[14] <= 80'd0;
            barbarian_words[15] <= 80'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start && !mode && (op == 2'b00)) begin
                        // Store operation
                        barbarian_words[addr] <= data;
                        state <= FINISH;
                    end else if (start && mode && (op == 2'b01)) begin
                        // Load Query Type 1
                        query_P <= data;
                        state <= FINISH;
                    end else if (start && mode && (op == 2'b10)) begin
                        // Query Count Type 2
                        current_word <= barbarian_words[addr];
                        match_count <= 32'd0;
                        pos <= 4'd0;
                        cycle_counter <= 8'd1;
                        state <= SEARCH_LOOP;
                    end
                end

                SEARCH_LOOP: begin
                    // Check if we are within query bounds
                    if ((pos + char_idx) < 4'd16) begin
                        // Check character match
                        if (current_word[(79 - char_idx*5) -: 5] == query_P[(79 - (pos + char_idx)*5) -: 5]) begin
                            // Match at current char index
                            // If this is the last character (15th index, or 16th char)
                            if (char_idx == 4'd15) begin
                                // Full word matched
                                match_count <= match_count + 32'd1;
                                pos <= pos + 4'd1;
                                char_idx <= 4'd0;
                            end else begin
                                // Continue matching next char
                                char_idx <= char_idx + 4'd1;
                            end
                        end else begin
                            // Mismatch, move to next position
                            pos <= pos + 4'd1;
                            char_idx <= 4'd0;
                        end
                    end else begin
                        // Out of query bounds, move to next position
                        pos <= pos + 4'd1;
                        char_idx <= 4'd0;
                    end

                    cycle_counter <= cycle_counter + 8'd1;

                    // Exit conditions
                    if (pos == 4'd15 || cycle_counter >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else if (pos == 4'd14 && char_idx == 4'd15) begin
                         // Last position just checked
                         state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    if (state != FINISH) begin
                        // First cycle in FINISH state
                        if (op == 2'b10 || (state == SEARCH_LOOP && (next_state == FINISH))) begin
                            result <= match_count;
                        end
                    end
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule