module substitution_cipher_matcher (
    input clk,
    input rst_n,
    input start,
    input [127:0] encrypted_msg,
    input [63:0] fragment,
    input [4:0] msg_len,
    input [3:0] frag_len,
    output reg [127:0] result_string,
    output reg [4:0] result_pos,
    output reg [7:0] match_count,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam CHECK_POSITION = 3'b010;
    localparam CHECK_MAPPING = 3'b011;
    localparam COUNT_UPDATES = 3'b100;
    localparam UPDATE_RESULT = 3'b101;
    localparam DONE = 3'b110;

    reg [2:0] state;
    reg [2:0] next_state;

    // Control registers
    reg [4:0] pos_cnt;           // Current position being checked (0 to msg_len - frag_len)
    reg [4:0] max_pos;           // msg_len - frag_len
    reg [3:0] char_idx;          // Index inside fragment (0 to frag_len - 1)
    reg [4:0] valid_count;       // Number of valid positions found
    reg [4:0] last_valid_pos;    // Store last valid position
    reg [127:0] last_valid_str;  // Store last valid substring

    // Mapping arrays: 26 entries for 'a'-'z' (index 0-25)
    // fwd_map[frag_char] = msg_char
    // inv_map[msg_char] = frag_char
    // 26 entries of 5 bits (0-25). 26 means no mapping
    reg [4:0] fwd_map [25:0];
    reg [4:0] inv_map [25:0];
    
    // Valid flag for mapping arrays
    reg mapping_valid;
    reg next_mapping_valid;

    // Helper: Extract char from msg (16 chars)
    wire [7:0] msg_char;
    wire [7:0] frag_char;
    
    // Compute current char indices
    // msg_char_index = pos_cnt + char_idx
    wire [4:0] msg_char_idx;
    assign msg_char_idx = pos_cnt + char_idx;

    // Extract characters from packed inputs
    // encrypted_msg[127:0], 16 bytes. MSB is char 0
    // We need to index 0-15. msg_char_idx is 0-15 max.
    assign msg_char = encrypted_msg[127 - (msg_char_idx * 8) -: 8];
    assign fragment[63 - (char_idx * 8) -: 8] = frag_char;

    // ASCII logic helpers
    wire [4:0] frag_char_idx_val;
    wire [4:0] msg_char_idx_val;
    assign frag_char_idx_val = frag_char - 8'h61; // 'a' is 0
    assign msg_char_idx_val = msg_char - 8'h61; // 'a' is 0

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
                else next_state = IDLE;
            end
            INIT: begin
                // If frag_len > msg_len or frag_len == 0, go directly to DONE
                if (frag_len == 0 || frag_len > msg_len) next_state = DONE;
                else next_state = CHECK_POSITION;
            end
            CHECK_POSITION: begin
                // Check if we have checked all positions
                if (pos_cnt > max_pos) next_state = DONE;
                else next_state = CHECK_MAPPING;
            end
            CHECK_MAPPING: begin
                // Check all chars in fragment
                if (char_idx < frag_len) next_state = CHECK_MAPPING;
                else next_state = COUNT_UPDATES;
            end
            COUNT_UPDATES: begin
                next_state = UPDATE_RESULT;
            end
            UPDATE_RESULT: begin
                // Prepare for next position or finish
                if (pos_cnt + 1 > max_pos) next_state = DONE;
                else next_state = CHECK_POSITION;
            end
            DONE: begin
                next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_string <= 128'h20202020202020202020202020202020; // Spaces
            result_pos <= 5'd0;
            match_count <= 8'd0;
            done <= 1'b0;
            pos_cnt <= 5'd0;
            max_pos <= 5'd0;
            char_idx <= 4'd0;
            valid_count <= 5'd0;
            last_valid_pos <= 5'd0;
            last_valid_str <= 128'd0;
            mapping_valid <= 1'b1;
            next_mapping_valid <= 1'b1;
            // Initialize maps (optional, but good practice)
            for (i = 0; i < 26; i = i + 1) begin
                fwd_map[i] <= 5'd26;
                inv_map[i] <= 5'd26;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end

                INIT: begin
                    // Reset counters and flags
                    pos_cnt <= 5'd0;
                    // max_pos = msg_len - frag_len (signed arithmetic careful)
                    max_pos <= msg_len - frag_len;
                    char_idx <= 4'd0;
                    valid_count <= 5'd0;
                    last_valid_pos <= 5'd0;
                    last_valid_str <= 128'd0;
                    mapping_valid <= 1'b1; // Assume valid initially
                    // Clear maps
                    for (i = 0; i < 26; i = i + 1) begin
                        fwd_map[i] <= 5'd26;
                        inv_map[i] <= 5'd26;
                    end
                end

                CHECK_POSITION: begin
                    // Start of a new position check
                    // Reset char index
                    char_idx <= 4'd0;
                    // Clear mapping validity for this position
                    mapping_valid <= 1'b1;
                    // Clear maps for this position check
                    for (i = 0; i < 26; i = i + 1) begin
                        fwd_map[i] <= 5'd26;
                        inv_map[i] <= 5'd26;
                    end
                    // Optimization: If we already found a valid match AND we need strictly 1 match (logic is later)
                    // Actually we need to find ALL matches to count them.
                    // But we only need the substring if count becomes 1.
                    // Just store the first valid one.
                end

                CHECK_MAPPING: begin
                    // Check one character pair
                    if (mapping_valid && char_idx < frag_len) begin
                        // Check bounds for message
                        if (msg_char_idx < msg_len) begin
                            // Check if characters are letters 'a'-'z' (implicitly handled by input assumption)
                            // Get indices
                            if (frag_char >= 8'h61 && frag_char <= 8'h7A && msg_char >= 8'h61 && msg_char <= 8'h7A) begin
                                // Check mapping
                                // fwd: frag_char_idx_val -> msg_char_idx_val
                                if (fwd_map[frag_char_idx_val] == 5'd26 && inv_map[msg_char_idx_val] == 5'd26) begin
                                    // New mapping
                                    fwd_map[frag_char_idx_val] <= msg_char_idx_val;
                                    inv_map[msg_char_idx_val] <= frag_char_idx_val;
                                end else begin
                                    // Existing mapping, check consistency
                                    if (fwd_map[frag_char_idx_val] != msg_char_idx_val || inv_map[msg_char_idx_val] != frag_char_idx_val) begin
                                        mapping_valid <= 1'b0;
                                    end
                                end
                            end else begin
                                // Invalid characters (not a-z)
                                mapping_valid <= 1'b0;
                            end
                            char_idx <= char_idx + 1;
                        end else begin
                            // Out of bounds message (should not happen if pos_cnt <= max_pos)
                            mapping_valid <= 1'b0;
                            char_idx <= char_idx + 1;
                        end
                    end else begin
                        // If already invalid or done with chars, just increment to finish state transition logic
                        // (State logic handles transition to COUNT_UPDATES)
                        // But we need to handle the loop flow.
                        // If char_idx < frag_len, we stay in this state. 
                        // If we invalidated early, we still need to step through to reach the end condition?
                        // No, let's just increment char_idx if we are in this state to ensure we exit the loop.
                        if (char_idx < frag_len) begin
                             char_idx <= char_idx + 1;
                        end
                    end
                end

                COUNT_UPDATES: begin
                    if (mapping_valid) begin
                        valid_count <= valid_count + 1;
                        last_valid_pos <= pos_cnt;
                        // Capture substring for this position
                        // We need to extract frag_len chars from encrypted_msg starting at pos_cnt
                        // This is tricky to do in one cycle or logic. 
                        // We can do it incrementally or just store the current substring from msg.
                        // Let's extract it directly based on pos_cnt.
                        // We need to build 16 bytes of output. 
                        // Result string format: The substring starting at pos_cnt, length frag_len, padded with spaces at the end.
                        // We can compute this now.
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < frag_len) begin
                                // Copy char from msg
                                // msg_index = pos_cnt + i
                                // If msg_index < msg_len (should be true since pos_cnt <= max_pos)
                                last_valid_str[127 - (i*8) -: 8] <= encrypted_msg[127 - ((pos_cnt + i)*8) -: 8];
                            end else begin
                                // Pad with space
                                last_valid_str[127 - (i*8) -: 8] <= 8'h20;
                            end
                        end
                    end
                end

                UPDATE_RESULT: begin
                    // Increment position counter
                    pos_cnt <= pos_cnt + 1;
                end

                DONE: begin
                    done <= 1'b1;
                    // Update outputs based on valid_count
                    match_count <= valid_count;
                    if (valid_count == 5'd1) begin
                        result_pos <= last_valid_pos;
                        result_string <= last_valid_str;
                    end else begin
                        result_pos <= 5'd0;
                        // result_string remains default or previous? 
                        // Spec says "output count only", implies string is don't care or default. 
                        // Let's clear it to spaces.
                        result_string <= 128'h20202020202020202020202020202020;
                    end
                end
            endcase
        end
    end

endmodule