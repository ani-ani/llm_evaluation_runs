module primitive_search_steps (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] query_word [0:7],
    input wire db_word_en,
    input wire [7:0] db_word [0:7],
    input wire [2:0] db_word_index,
    output reg [15:0] result,
    output reg done
);

    // Database storage: 8 words x 8 bytes x 8 bits
    reg [7:0] database [0:7][0:7];
    
    // State encoding
    localparam IDLE = 2'b00;
    localparam LOAD_DB = 2'b01;
    localparam PROCESSING = 2'b10;
    localparam DONE = 2'b11;
    
    reg [1:0] current_state, next_state;
    
    // Processing registers
    reg [2:0] word_idx;          // Current database word index (0-7)
    reg [3:0] byte_idx;          // Current byte index for LCP (0-8, where 8 indicates complete)
    reg [15:0] step_accumulator; // Accumulated steps
    reg match_found;             // Flag to indicate exact match found
    reg [15:0] lcp_count;        // LCP counter for current word
    reg processing_word;         // Flag indicating we are processing a word
    
    // Temporary storage for comparison
    reg [7:0] current_db_word [0:7];
    
    // LCP calculation signals
    wire [7:0] byte_match [0:7];
    wire [2:0] lcp_value;
    
    // Parallel byte comparison for LCP calculation
    // Calculate match for each byte position
    assign byte_match[0] = {8{query_word[0] == current_db_word[0]}};
    assign byte_match[1] = {8{query_word[1] == current_db_word[1]}};
    assign byte_match[2] = {8{query_word[2] == current_db_word[2]}};
    assign byte_match[3] = {8{query_word[3] == current_db_word[3]}};
    assign byte_match[4] = {8{query_word[4] == current_db_word[4]}};
    assign byte_match[5] = {8{query_word[5] == current_db_word[5]}};
    assign byte_match[6] = {8{query_word[6] == current_db_word[6]}};
    assign byte_match[7] = {8{query_word[7] == current_db_word[7]}};
    
    // Priority encoder to find LCP length (0-8)
    // If bytes match up to index i, LCP is i+1 (if all match up to i)
    // Logic: Check which bytes match, count prefix
    // Implementation: Use reduction AND to check all bytes up to a point
    wire all_0_match = &byte_match[0];
    wire all_1_match = &byte_match[0] & &byte_match[1];
    wire all_2_match = &byte_match[0] & &byte_match[1] & &byte_match[2];
    wire all_3_match = &byte_match[0] & &byte_match[1] & &byte_match[2] & &byte_match[3];
    wire all_4_match = &byte_match[0] & &byte_match[1] & &byte_match[2] & &byte_match[3] & &byte_match[4];
    wire all_5_match = &byte_match[0] & &byte_match[1] & &byte_match[2] & &byte_match[3] & &byte_match[4] & &byte_match[5];
    wire all_6_match = &byte_match[0] & &byte_match[1] & &byte_match[2] & &byte_match[3] & &byte_match[4] & &byte_match[5] & &byte_match[6];
    wire all_7_match = &byte_match[0] & &byte_match[1] & &byte_match[2] & &byte_match[3] & &byte_match[4] & &byte_match[5] & &byte_match[6] & &byte_match[7];
    
    // Compute LCP value combinational logic
    always @(*) begin
        if (all_7_match) lcp_value = 3'd7;
        else if (all_6_match) lcp_value = 3'd6;
        else if (all_5_match) lcp_value = 3'd5;
        else if (all_4_match) lcp_value = 3'd4;
        else if (all_3_match) lcp_value = 3'd3;
        else if (all_2_match) lcp_value = 3'd2;
        else if (all_1_match) lcp_value = 3'd1;
        else if (all_0_match) lcp_value = 3'd0;
        else lcp_value = 3'd0;
    end
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start && (db_word_en || db_word_index == 3'd0)) // Wait for at least some data or explicit start
                    next_state = PROCESSING; // Requirement implies loading happens before or during, but we start process on start
                else if (db_word_en)
                    next_state = LOAD_DB;
                else
                    next_state = IDLE;
            end
            LOAD_DB: begin
                if (db_word_en)
                    next_state = LOAD_DB; // Stay loading if enabled
                else if (start)
                    next_state = PROCESSING; // Start processing after loading
                else
                    next_state = LOAD_DB;
            end
            PROCESSING: begin
                // Logic inside state to check for completion
                // We stay in PROCESSING until all words done or match found
                // If we are at the end of a word comparison and (match or last word), go DONE
                // This is handled in the sequential logic below
                next_state = PROCESSING; // Default
            end
            DONE: begin
                if (!start && !db_word_en) next_state = IDLE; // Wait for reset of inputs
                else next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Output and datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'd0;
            done <= 1'b0;
            word_idx <= 3'd0;
            byte_idx <= 4'd0;
            step_accumulator <= 16'd0;
            match_found <= 1'b0;
            lcp_count <= 16'd0;
            processing_word <= 1'b0;
            // Clear database (optional, but good practice)
            // We can't clear the whole array in one go easily in synthesis without loops, 
            // but initial block handles it if supported, otherwise rely on valid flags if needed.
        end else begin
            case (current_state)
                IDLE: begin
                    if (db_word_en) begin
                        // Store word immediately if in IDLE
                        database[db_word_index] <= db_word;
                    end
                    // Initialize processing variables if transitioning to process
                    if (start) begin
                        word_idx <= 3'd0;
                        step_accumulator <= 16'd0;
                        match_found <= 1'b0;
                        processing_word <= 1'b1;
                        byte_idx <= 4'd0;
                        done <= 1'b0;
                    end
                end
                
                LOAD_DB: begin
                    if (db_word_en) begin
                        database[db_word_index] <= db_word;
                    end
                    if (start) begin
                        word_idx <= 3'd0;
                        step_accumulator <= 16'd0;
                        match_found <= 1'b0;
                        processing_word <= 1'b1;
                        byte_idx <= 4'd0;
                        done <= 1'b0;
                    end
                end
                
                PROCESSING: begin
                    // If we were just transitioning in, we might need to latch DB word
                    // But we read from DB array, so it should be ready.
                    
                    if (processing_word) begin
                        // Load current DB word for comparison (if we haven't already)
                        // We assume it takes 0 cycle to read from block RAM in this logic for simplicity in state machine
                        // Or we can load it one cycle ahead. Let's load it now.
                        
                        // Logic: Process bytes 0 to 7
                        // Wait for LCP result (combinational)
                        // Add to accumulator
                        // Check match
                        // Increment word_idx or stop
                        
                        // Actually, to meet timing and structure, we do this in stages within the state
                        // We'll use byte_idx to track progress.
                        
                        if (byte_idx == 4'd0) begin
                            // First cycle of processing a word: Calculate LCP and Match
                            current_db_word <= database[word_idx];
                            
                            // LCP calculation is combinational based on current_db_word and query_word
                            // However, current_db_word is just updated, so we need a delay or latch it.
                            // Let's read DB inside the combinational block or register it.
                            // Since we are in clocked block, we rely on 'current_db_word' being loaded.
                            // Wait one cycle for LCP logic to settle? 
                            // To minimize latency, we calculate LCP based on 'database[word_idx]' directly if possible,
                            // but we can't call array inside combinational block usually for synthesis of multi-dim arrays easily in all tools.
                            // Let's stick to the registered 'current_db_word'.
                            
                            byte_idx <= 4'd1; // Move to next state of this word
                        end else if (byte_idx == 4'd1) begin
                            // Cycle 2: Use LCP result
                            // Check Exact Match (all_7_match)
                            // Add (1 + LCP) to accumulator
                            
                            // LCP calculation logic uses current_db_word (loaded in prev cycle) and query_word
                            // We need to re-evaluate the wire logic here. 
                            // Since wires are combinational, we just read the result.
                            // But we need to ensure 'current_db_word' is stable. 
                            // So we read DB at byte_idx=0, calculate LCP at byte_idx=1.
                            
                            // Recalculate LCP locally or use the wires? The wires depend on the module inputs.
                            // We can reconstruct the LCP check here or use the logic.
                            
                            // Let's implement the LCP check logic directly here to be robust
                            // We need to access the database array. We can access it directly since it's a reg array.
                            // But 'current_db_word' holds the data.
                            
                            // Calculate Match and LCP for the word loaded in previous cycle
                            // Note: 'current_db_word' now holds database[word_idx]
                            
                            // Check exact match
                            if ( (query_word[0] == current_db_word[0]) &&
                                 (query_word[1] == current_db_word[1]) &&
                                 (query_word[2] == current_db_word[2]) &&
                                 (query_word[3] == current_db_word[3]) &&
                                 (query_word[4] == current_db_word[4]) &&
                                 (query_word[5] == current_db_word[5]) &&
                                 (query_word[6] == current_db_word[6]) &&
                                 (query_word[7] == current_db_word[7]) ) begin
                                
                                // Exact Match found
                                step_accumulator <= step_accumulator + 1 + 8; // 1 + LCP(8)
                                match_found <= 1'b1;
                                // We are done after this word
                                // But we need to transition state.
                                // We set a flag to exit processing loop
                                processing_word <= 1'b0;
                                result <= step_accumulator + 1 + 8;
                                done <= 1'b1;
                                current_state <= DONE;
                            end else begin
                                // Not exact match, calculate LCP
                                // We need the LCP length.
                                // Re-implement priority check for LCP here or use the wire logic?
                                // Wires are safer if correctly connected.
                                // Let's assume the wires `all_X_match` are updated based on current_db_word.
                                // However, `current_db_word` was updated at byte_idx=0, so now at byte_idx=1 wires are valid.
                                
                                // Compute LCP length (0-7)
                                reg [3:0] current_lcp;
                                current_lcp = 0;
                                if (query_word[0] == current_db_word[0]) current_lcp = 1;
                                if (query_word[0] == current_db_word[0] && query_word[1] == current_db_word[1]) current_lcp = 2;
                                if (query_word[0] == current_db_word[0] && query_word[1] == current_db_word[1] && query_word[2] == current_db_word[2]) current_lcp = 3;
                                if (query_word[0] == current_db_word[0] && query_word[1] == current_db_word[1] && query_word[2] == current_db_word[2] && query_word[3] == current_db_word[3]) current_lcp = 4;
                                if (query_word[0] == current_db_word[0] && query_word[1] == current_db_word[1] && query_word[2] == current_db_word[2] && query_word[3] == current_db_word[3] && query_word[4] == current_db_word[4]) current_lcp = 5;
                                if (query_word[0] == current_db_word[0] && query_word[1] == current_db_word[1] && query_word[2] == current_db_word[2] && query_word[3] == current_db_word[3] && query_word[4] == current_db_word[4] && query_word[5] == current_db_word[5]) current_lcp = 6;
                                if (query_word[0] == current_db_word[0] && query_word[1] == current_db_word[1] && query_word[2] == current_db_word[2] && query_word[3] == current_db_word[3] && query_word[4] == current_db_word[4] && query_word[5] == current_db_word[5] && query_word[6] == current_db_word[6]) current_lcp = 7;
                                
                                step_accumulator <= step_accumulator + 1 + current_lcp;
                                
                                // Move to next word
                                if (word_idx == 3'd7) begin
                                    // Last word, no match
                                    processing_word <= 1'b0;
                                    result <= step_accumulator + 1 + current_lcp;
                                    done <= 1'b1;
                                    current_state <= DONE;
                                end else begin
                                    word_idx <= word_idx + 1;
                                    byte_idx <= 4'd0; // Reset for next word
                                    // Stay in PROCESSING state
                                end
                            end
                        end
                    end
                end
                
                DONE: begin
                    // Hold outputs
                    done <= 1'b1;
                    // result is already set
                    // Reset internal flags if needed for next start
                    if (!start && !db_word_en) begin
                        done <= 1'b0;
                        result <= 16'd0;
                    end
                end
            endcase
        end
    end

endmodule
