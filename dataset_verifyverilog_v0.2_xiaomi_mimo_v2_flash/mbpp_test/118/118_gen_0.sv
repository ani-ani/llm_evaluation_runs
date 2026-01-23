module string_splitter (
    input clk,
    input rst_n,
    input start,
    input [7:0] input_string [15:0],
    output reg [7:0] word1 [15:0],
    output reg [7:0] word2 [15:0],
    output reg [7:0] word3 [15:0],
    output reg [2:0] word_count,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam SCAN = 2'b01;
    localparam EXTRACT = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] current_state;
    reg [1:0] next_state;

    // Internal registers
    reg [3:0] scan_ptr;        // Pointer for scanning input (0-15)
    reg [4:0] timer;           // Timer for 20-cycle requirement
    
    // Storage for word metadata discovered during scan
    reg [2:0] found_word_mask; // Bitmask for words 0, 1, 2
    reg [3:0] word_start_idx [0:2];
    reg [3:0] word_len_reg [0:2];
    
    // Control flags
    reg scanning_word;         // True if currently inside a word during scan
    reg [1:0] active_word_cnt; // Count of words currently stored in metadata

    integer i;

    // State Transition Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = SCAN;
                else next_state = IDLE;
            end
            SCAN: begin
                if (scan_ptr == 15) next_state = EXTRACT;
                else next_state = SCAN;
            end
            EXTRACT: begin
                // Wait here until 20 cycles have passed (timer reaches 19)
                // Timer starts counting from 1 when leaving IDLE.
                // If timer >= 19, we are done.
                if (timer >= 19) next_state = DONE;
                else next_state = EXTRACT;
            end
            DONE: begin
                next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            scan_ptr <= 4'b0;
            timer <= 5'b0;
            found_word_mask <= 3'b0;
            scanning_word <= 1'b0;
            active_word_cnt <= 2'b0;
            word_count <= 3'b0;
            done <= 1'b0;
            
            // Initialize outputs with spaces (0x20)
            for (i = 0; i < 16; i = i + 1) begin
                word1[i] <= 8'h20;
                word2[i] <= 8'h20;
                word3[i] <= 8'h20;
            end
        end else begin
            current_state <= next_state;
            
            // Default timer behavior: Increment if we are not in IDLE (or if we are transitioning out of IDLE)
            // Actually, we should increment when we are in SCAN, EXTRACT, or DONE, provided we started.
            // Let's handle timer logic inside the case statement for clarity.

            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    timer <= 5'b0; // Reset timer
                    scan_ptr <= 4'b0;
                    found_word_mask <= 3'b0;
                    scanning_word <= 1'b0;
                    active_word_cnt <= 2'b0;
                    
                    // Reset outputs if desired, or just leave them (valid only when done is high)
                    // Prompt says "In IDLE state..." Usually outputs hold last value or reset. 
                    // Let's reset outputs to spaces for cleanliness.
                    // (Optimized: Only reset if needed, but here we do full reset for robustness)
                    for (i = 0; i < 16; i = i + 1) begin
                        word1[i] <= 8'h20;
                        word2[i] <= 8'h20;
                        word3[i] <= 8'h20;
                    end
                    word_count <= 3'b0;
                end

                SCAN: begin
                    // Increment timer
                    timer <= timer + 1;
                    
                    // Perform Scan Logic
                    // Read current character
                    if (input_string[scan_ptr] != 8'h20) begin
                        // Non-space character
                        if (!scanning_word) begin
                            // Start of a new word
                            if (active_word_cnt < 3) begin
                                word_start_idx[active_word_cnt] <= scan_ptr;
                                word_len_reg[active_word_cnt] <= 4'd1;
                                found_word_mask[active_word_cnt] <= 1'b1;
                                active_word_cnt <= active_word_cnt + 1;
                            end else begin
                                // Ignore words beyond the 3rd (mask remains 0 for this word, but we count it as 'started' internally to skip)
                                // Actually, we should just mark scanning_word as true but not store metadata.
                            end
                            scanning_word <= 1'b1;
                        end else begin
                            // Continuation of current word
                            if (active_word_cnt > 0 && active_word_cnt <= 3) begin
                                // Update length of the last active word (index = active_word_cnt - 1)
                                word_len_reg[active_word_cnt - 1] <= word_len_reg[active_word_cnt - 1] + 1;
                            end
                        end
                    end else begin
                        // Space character encountered
                        scanning_word <= 1'b0;
                    end

                    // Increment scan pointer
                    if (scan_ptr < 15)
                        scan_ptr <= scan_ptr + 1;
                    else 
                        scan_ptr <= 15; // Keep at 15 for boundary check
                end

                EXTRACT: begin
                    // Increment timer
                    timer <= timer + 1;
                    
                    // Perform Extraction (one-cycle burst fill based on stored indices)
                    // We must fill word1, word2, word3 arrays (16 chars each) based on input_string.
                    // Since this is a combinational-like operation inside a sequential block, 
                    // we can iterate and assign in this single clock cycle.
                    // This creates a large combinational path, but meets the timing requirement.
                    
                    // Initialize all outputs to spaces first (just in case)
                    for (i = 0; i < 16; i = i + 1) begin
                        word1[i] <= 8'h20;
                        word2[i] <= 8'h20;
                        word3[i] <= 8'h20;
                    end
                    
                    // Copy characters for valid words
                    // Word 0
                    if (found_word_mask[0]) begin
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < word_len_reg[0]) begin
                                word1[i] <= input_string[word_start_idx[0] + i];
                            end
                        end
                    end
                    // Word 1
                    if (found_word_mask[1]) begin
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < word_len_reg[1]) begin
                                word2[i] <= input_string[word_start_idx[1] + i];
                            end
                        end
                    end
                    // Word 2
                    if (found_word_mask[2]) begin
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < word_len_reg[2]) begin
                                word3[i] <= input_string[word_start_idx[2] + i];
                            end
                        end
                    end
                    
                    // Update word_count output
                    word_count <= {found_word_mask[2], found_word_mask[1], found_word_mask[0]};
                    
                    // Note: The loops above are unrolled during synthesis. 
                    // It's 3x16 = 48 assignments. 
                end

                DONE: begin
                    done <= 1'b1;
                    // Hold outputs
                end
            endcase
        end
    end
endmodule