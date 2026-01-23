module pattern_matcher(
    input clk,
    input rst_n,
    input start,
    input valid_in,
    input [5:0] char_in,
    input is_delete_file,
    input file_end,
    input files_done,
    output reg result_valid,
    output reg [0:0] yes_no,
    output reg [127:0] pattern,
    output reg [3:0] pattern_len
);

    // Internal state definition
    localparam IDLE = 3'b000;
    localparam READ_DELETE = 3'b001;
    localparam READ_NORMAL = 3'b010;
    localparam CHECK = 3'b011;
    localparam DONE = 3'b100;

    // Internal Registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    // File tracking
    reg [2:0] delete_file_count; // Tracks number of delete files processed
    reg [2:0] normal_file_count; // Tracks number of normal files processed
    reg files_processed_done;     // Flag to indicate all files read
    
    // Character buffer for current file being read (16 chars x 6 bits)
    reg [5:0] char_buffer [0:15];
    reg [3:0] char_index;         // Index for current character in file
    reg [3:0] current_len;        // Length of current file being read
    
    // Pattern Buffer (16 chars x 6 bits)
    reg [5:0] pattern_buf [0:15];
    reg [3:0] pattern_len_buf;    // Length of the pattern (from first delete file)
    reg pattern_len_error;        // Flag if delete files have different lengths
    
    // Match flags
    reg current_file_matches_pattern; // Flag if current normal file matches
    reg any_normal_matched;           // Flag if any normal file matched (result is NO)
    
    // Control signals
    reg char_buffer_clear;
    reg char_buffer_store;
    reg pattern_init;
    reg pattern_update;
    
    integer i;

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && valid_in && !file_end && !files_done) begin
                    // Start processing first character of first file
                    if (is_delete_file) next_state = READ_DELETE;
                    else next_state = READ_NORMAL; // Should not happen initially but handled
                end else begin
                    next_state = IDLE;
                end
            end

            READ_DELETE: begin
                if (file_end) begin
                    // Check if this was the last file
                    if (files_done && char_index == 0) begin // Files done signal logic might vary, let's rely on file_end + files_done pair or simple count if strictly sequential
                         // Actually, let's check files_done on the cycle after file_end or check count logic
                         // Assuming files_done is asserted with the last file_end
                         // If file_end of last delete file, transition to CHECK (if no normal files) or READ_NORMAL (if we expect normal files)
                         // Since we don't know if there are normal files until we see one or files_done, we need to handle carefully.
                         // Let's assume files_done means 'no more files of any kind'.
                         next_state = CHECK;
                    end else begin
                         next_state = READ_NORMAL; // Usually delete files come first, then normal. 
                    end
                end else if (valid_in) begin
                    next_state = READ_DELETE;
                end else begin
                    next_state = READ_DELETE;
                end
                // Refinement: If files_done is high, go to CHECK directly
                if (files_done && file_end) next_state = CHECK;
            end

            READ_NORMAL: begin
                if (file_end) begin
                    if (files_done) begin
                        next_state = CHECK;
                    end else begin
                        next_state = READ_NORMAL;
                    end
                end else if (valid_in) begin
                    next_state = READ_NORMAL;
                end else begin
                    next_state = READ_NORMAL;
                end
            end

            CHECK: begin
                // One cycle to compute final result
                next_state = DONE;
            end

            DONE: begin
                // Stay here until reset or start again (implicit idle behavior)
                if (start) next_state = IDLE; // Restart capability
                else next_state = DONE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all internal registers
            result_valid <= 1'b0;
            yes_no <= 1'b0;
            pattern <= 128'b0;
            pattern_len <= 4'b0;
            delete_file_count <= 3'b0;
            normal_file_count <= 3'b0;
            files_processed_done <= 1'b0;
            char_index <= 4'b0;
            current_len <= 4'b0;
            pattern_len_buf <= 4'b0;
            pattern_len_error <= 1'b0;
            any_normal_matched <= 1'b0;
            current_file_matches_pattern <= 1'b0;
            
            // Reset buffers (optional but good practice)
            for (i = 0; i < 16; i = i + 1) begin
                char_buffer[i] <= 6'b0;
                pattern_buf[i] <= 6'b0;
            end
        end else begin
            // Default control signals to prevent latches
            char_buffer_clear <= 1'b0;
            char_buffer_store <= 1'b0;
            pattern_init <= 1'b0;
            pattern_update <= 1'b0;

            case (state)
                IDLE: begin
                    if (start && valid_in && !file_end) begin
                        // First character of first file
                        if (is_delete_file) begin
                            // Initialize for first delete file
                            char_buffer[0] <= char_in;
                            char_index <= 4'd1;
                            current_len <= 4'd0; // Will be 1 after this char, but we use index count mainly
                            // Pattern Init logic happens here effectively for first file
                            pattern_buf[0] <= char_in;
                            pattern_len_buf <= 4'd0; // Temp length, finalized at file_end
                            pattern_len_error <= 1'b0;
                            delete_file_count <= 3'd1;
                        end else begin
                            // First normal file (unexpected if delete files always first, but handled)
                            char_buffer[0] <= char_in;
                            char_index <= 4'd1;
                            normal_file_count <= 3'd1;
                            // Comparison logic (requires pattern to be ready, so this case is complex)
                            // Assuming strict ordering: Delete files first, then Normal.
                        end
                    end
                end

                READ_DELETE: begin
                    if (valid_in) begin
                        if (!file_end) begin
                            // Store character in buffer and pattern
                            if (char_index < 16) begin
                                char_buffer[char_index] <= char_in;
                                pattern_buf[char_index] <= char_in;
                                char_index <= char_index + 1'b1;
                            end
                        end
                    end
                    
                    if (file_end) begin
                        // End of current file
                        current_len <= char_index;
                        
                        if (delete_file_count == 1) begin
                            // First delete file finished: Establish baseline pattern
                            pattern_len_buf <= char_index;
                            pattern_len <= char_index;
                        end else begin
                            // Subsequent delete files: Compare with pattern
                            // Compare lengths
                            if (char_index != pattern_len_buf) begin
                                pattern_len_error <= 1'b1;
                            end else begin
                                // Compare characters position by position (combinational compare logic here)
                                // Since we are in sequential block, we must compare stored buffers.
                                // We can do this iteratively or assume previous cycle comparisons.
                                // Let's do the comparison now based on stored char_buffer and pattern_buf.
                                // Note: char_buffer holds current file. pattern_buf holds the master pattern (which might be updated from previous file or is baseline).
                                // We need to update pattern_buf based on mismatches.
                                // Since we have single cycle per char usually, but file_end is a flag, we can iterate here.
                                // However, Verilog logic must be static. We can use a loop to check mismatches.
                                for (i = 0; i < 16; i = i + 1) begin
                                    if (i < char_index) begin
                                        // Compare current file char with stored pattern char
                                        // If they differ, update pattern to '?'
                                        if (char_buffer[i] != pattern_buf[i]) begin
                                            pattern_buf[i] <= 6'h3F; // '?' ASCII
                                        end
                                    end
                                end
                            end
                        end
                        
                        // Update File Count
                        delete_file_count <= delete_file_count + 1'b1;
                        
                        // Prepare for next file or transition
                        char_index <= 4'b0;
                        
                        // Check transition conditions handled by next_state, but we need to detect if we switch to READ_NORMAL
                        // If files_done, we go to CHECK. If not, we might go to READ_NORMAL or continue READ_DELETE if logic changes.
                        // Based on next_state logic: 
                        // If files_done, next_state is CHECK.
                        // If !files_done, next_state is READ_NORMAL (assuming delete files block is done).
                        // Wait, the problem says "Input Interface: Accepts files one by one".
                        // It doesn't strictly say "Delete files first, then Normal". 
                        // To be safe, we should check is_delete_file on the next cycle.
                        // However, since we are updating state based on next_state, we just need to clear buffer.
                        
                        char_buffer_clear <= 1'b1; // Reset char buffer for next file
                    end
                end

                READ_NORMAL: begin
                    if (valid_in) begin
                        if (!file_end) begin
                            if (char_index < 16) begin
                                char_buffer[char_index] <= char_in;
                                char_index <= char_index + 1'b1;
                            end
                        end
                    end
                    
                    if (file_end) begin
                        // End of normal file: Check match against pattern
                        current_len <= char_index;
                        
                        // Check match condition: Length match AND characters match (or pattern has '?')
                        // 1. Length must match pattern_len_buf (unless pattern_len_error is already set, but that applies to delete files)
                        // Note: If delete files had mismatched lengths, we might have set error, but let's assume validation continues.
                        // If pattern_len_buf != current_len, it's a mismatch -> NO MATCH.
                        
                        // We need to detect if this file matches. 
                        // Match condition: (length == pattern_len) AND (all chars match or pattern has ?)
                        // If Match -> Result is NO (fail).
                        
                        if (char_index == pattern_len_buf && !pattern_len_error) begin
                            // Check chars
                            // Assume match initially
                            reg file_mismatch;
                            file_mismatch = 1'b0;
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i < char_index) begin
                                    // If pattern is NOT '?' and chars differ, mismatch
                                    if (pattern_buf[i] != 6'h3F && pattern_buf[i] != char_buffer[i]) begin
                                        file_mismatch = 1'b1;
                                    end
                                end
                            end
                            
                            if (!file_mismatch) begin
                                any_normal_matched <= 1'b1;
                            end
                        end
                        
                        normal_file_count <= normal_file_count + 1'b1;
                        char_index <= 4'b0;
                        char_buffer_clear <= 1'b1;
                    end
                end

                CHECK: begin
                    // Determine final result
                    if (pattern_len_error) begin
                        yes_no <= 1'b0; // No
                    end else if (any_normal_matched) begin
                        yes_no <= 1'b0; // No
                    end else begin
                        yes_no <= 1'b1; // Yes
                    end
                    
                    // Pack pattern buffer into output vector
                    // pattern is [127:0], 16 chars x 8 bits. We use 6 bits stored + 2 bits padding?
                    // Output spec: 16 chars x 8 bits. Inputs are 6-bit ASCII. 
                    // We should pad with zeros or spaces. Let's pad with zeros.
                    pattern <= 128'b0;
                    for (i = 0; i < 16; i = i + 1) begin
                        // pattern[8*i +: 8] = {2'b00, pattern_buf[i]} OR just 8-bit ASCII?
                        // char_in is 6-bit. ASCII 'a' is 0x61 (97). 'A' is 0x41.
                        // Let's assume lower 6 bits of ASCII. Or map? 
                        // "covers lowercase letters, digits, '.'" -> usually ASCII 0x30-0x7A.
                        // 6 bits can cover range 0x30-0x7F? 0x30 is 48. 0x7F is 127. 
                        // 6 bits (0-63) is insufficient for full ASCII. 
                        // Let's assume the input is a compact code and we need to output full ASCII/8-bit.
                        // Let's map 6-bit to lower 6 bits of the byte, MSBs zero.
                        pattern[i*8 +: 8] <= {2'b00, pattern_buf[i]};
                    end
                    
                    pattern_len <= pattern_len_buf;
                    result_valid <= 1'b1;
                end

                DONE: begin
                    // Wait for reset or start
                    if (start) begin
                        result_valid <= 1'b0;
                        yes_no <= 1'b0;
                        pattern <= 128'b0;
                        pattern_len <= 4'b0;
                        delete_file_count <= 3'b0;
                        normal_file_count <= 3'b0;
                        files_processed_done <= 1'b0;
                        char_index <= 4'b0;
                        current_len <= 4'b0;
                        pattern_len_buf <= 4'b0;
                        pattern_len_error <= 1'b0;
                        any_normal_matched <= 1'b0;
                        current_file_matches_pattern <= 1'b0;
                        for (i = 0; i < 16; i = i + 1) begin
                            char_buffer[i] <= 6'b0;
                            pattern_buf[i] <= 6'b0;
                        end
                    end
                end
            endcase
        end
    end
endmodule