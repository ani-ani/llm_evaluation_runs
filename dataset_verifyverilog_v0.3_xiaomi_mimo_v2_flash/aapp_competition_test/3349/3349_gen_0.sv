module no_vowels_reconstructor (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] message,
    input wire [4:0] msg_len,
    input wire [255:0] skeleton_chars,
    input wire [15:0] skeleton_len,
    input wire [15:0] vowel_count,
    input wire [3:0] num_words,
    output reg word_valid,
    output reg [1:0] word_index,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE           = 4'd0;
    localparam [3:0] DP_INIT        = 4'd1;
    localparam [3:0] DP_LOOP        = 4'd2;
    localparam [3:0] DP_CHECK_WORD  = 4'd3;
    localparam [3:0] DP_COMPARE_CHAR = 4'd4;
    localparam [3:0] DP_UPDATE      = 4'd5;
    localparam [3:0] BACKTRACK      = 4'd6;
    localparam [3:0] OUTPUT         = 4'd7;
    localparam [3:0] DONE           = 4'd8;

    reg [3:0] state, next_state;

    // Maximum parameters
    localparam [4:0] MAX_MSG = 5'd16;
    localparam [3:0] MAX_WORDS_PARAM = 4'd4;
    localparam [3:0] MAX_LEN = 4'd8;

    // Registers for unpacked data
    reg [7:0] msg_reg [0:15];  // 16 chars, 8 bits each
    reg [7:0] dict_skeleton [0:3][0:7];  // 4 words, 8 chars max
    reg [3:0] dict_len [0:3];  // Lengths for 4 words
    reg [3:0] dict_vowels [0:3];  // Vowel counts for 4 words

    // DP registers
    reg [7:0] dp [0:16];  // Max vowels for prefix length
    reg reachable [0:16];  // Is prefix reachable
    reg [4:0] prev [0:16];  // Previous position
    reg [2:0] word_used [0:16];  // Word index used

    // Control registers
    reg [4:0] i;  // Position counter (0 to msg_len)
    reg [3:0] w;  // Word index counter (0 to num_words-1)
    reg [3:0] j;  // Character comparison counter
    reg [4:0] pos;  // Backtrack position
    reg [7:0] new_vowels;
    reg [4:0] stack [0:15];  // Stack for word indices (max 16)
    reg [4:0] stack_ptr;  // Stack pointer
    reg [4:0] output_ptr;  // Output pointer
    reg [3:0] word_len;  // Current word length
    reg match_flag;  // Character match flag
    reg [7:0] cycle_count;  // Safety counter
    localparam [7:0] MAX_CYCLES = 8'd200;  // Sufficient for 16x4x8 operations

    integer k;  // Loop variable for initialization

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            word_valid <= 1'b0;
            word_index <= 2'd0;
            done <= 1'b0;
            
            // Unpack message (index 0 is MSB)
            for (k = 0; k < 16; k = k + 1) begin
                msg_reg[15 - k] <= message[k*8 +: 8];
            end
            
            // Unpack skeleton data
            for (k = 0; k < 4; k = k + 1) begin
                dict_len[k] <= skeleton_len[k*4 +: 4];
                dict_vowels[k] <= vowel_count[k*4 +: 4];
                // Unpack chars (MSB first)
                for (int m = 0; m < 8; m = m + 1) begin
                    dict_skeleton[k][7 - m] <= skeleton_chars[k*64 + m*8 +: 8];
                end
            end
            
            // Initialize DP arrays
            for (k = 0; k < 17; k = k + 1) begin
                dp[k] <= 8'd0;
                reachable[k] <= 1'b0;
                prev[k] <= 5'd0;
                word_used[k] <= 3'd0;
            end
            
            // Initialize control registers
            i <= 5'd0;
            w <= 4'd0;
            j <= 4'd0;
            pos <= 5'd0;
            stack_ptr <= 5'd0;
            output_ptr <= 5'd0;
            new_vowels <= 8'd0;
            match_flag <= 1'b0;
            cycle_count <= 8'd0;
            word_len <= 4'd0;
            
            // Stack initialization
            for (k = 0; k < 16; k = k + 1) begin
                stack[k] <= 5'd0;
            end
            
        end else begin
            // Default outputs
            word_valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Reset cycle counter
                        cycle_count <= 8'd0;
                    end
                end
                
                DP_INIT: begin
                    // Initialize position 0 as reachable
                    reachable[0] <= 1'b1;
                    dp[0] <= 8'd0;
                    i <= 5'd0;
                    w <= 4'd0;
                    j <= 4'd0;
                end
                
                DP_LOOP: begin
                    if (i < msg_len) begin
                        if (reachable[i]) begin
                            w <= 4'd0;  // Reset word counter for new position
                        end
                        // If position not reachable, skip
                        if (!reachable[i]) begin
                            i <= i + 5'd1;
                        end
                    end
                end
                
                DP_CHECK_WORD: begin
                    if (w < num_words) begin
                        word_len <= dict_len[w];
                        // Check if word fits
                        if (i + dict_len[w] <= msg_len) begin
                            j <= 4'd0;
                            match_flag <= 1'b1;  // Assume match initially
                        end else begin
                            w <= w + 4'd1;
                        end
                    end
                end
                
                DP_COMPARE_CHAR: begin
                    if (j < word_len) begin
                        // Compare message[i+j] with dict_skeleton[w][j]
                        if (msg_reg[i + j] != dict_skeleton[w][j]) begin
                            match_flag <= 1'b0;
                        end
                        j <= j + 4'd1;
                    end
                end
                
                DP_UPDATE: begin
                    if (match_flag) begin
                        new_vowels <= dp[i] + dict_vowels[w];
                        // Update if better or first reach
                        if (!reachable[i + word_len] || new_vowels > dp[i + word_len]) begin
                            dp[i + word_len] <= new_vowels;
                            reachable[i + word_len] <= 1'b1;
                            prev[i + word_len] <= i;
                            word_used[i + word_len] <= w;
                        end
                    end
                    w <= w + 4'd1;  // Next word
                end
                
                BACKTRACK: begin
                    if (pos > 5'd0) begin
                        // Push word index onto stack
                        stack[stack_ptr] <= word_used[pos];
                        stack_ptr <= stack_ptr + 5'd1;
                        pos <= prev[pos];
                    end
                end
                
                OUTPUT: begin
                    if (output_ptr < stack_ptr) begin
                        word_index <= stack[output_ptr][1:0];
                        word_valid <= 1'b1;
                        output_ptr <= output_ptr + 5'd1;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Combinational next state logic
    always @(*) begin
        next_state = state;  // Default stay in current state
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = DP_INIT;
                end
            end
            
            DP_INIT: begin
                next_state = DP_LOOP;
            end
            
            DP_LOOP: begin
                if (i >= msg_len) begin
                    // Check if position msg_len is reachable
                    if (reachable[msg_len]) begin
                        next_state = BACKTRACK;
                    end else begin
                        next_state = DONE;  // No valid segmentation
                    end
                end else if (reachable[i]) begin
                    next_state = DP_CHECK_WORD;
                end else begin
                    // Skip unreachable positions
                    if (i + 5'd1 <= msg_len) begin
                        next_state = DP_LOOP;
                    end else begin
                        if (reachable[msg_len]) begin
                            next_state = BACKTRACK;
                        end else begin
                            next_state = DONE;
                        end
                    end
                end
            end
            
            DP_CHECK_WORD: begin
                if (w >= num_words) begin
                    next_state = DP_LOOP;
                end else if (i + dict_len[w] > msg_len) begin
                    // Word too long, skip
                    next_state = DP_CHECK_WORD;
                end else begin
                    next_state = DP_COMPARE_CHAR;
                end
            end
            
            DP_COMPARE_CHAR: begin
                if (j >= word_len) begin
                    next_state = DP_UPDATE;
                end else begin
                    next_state = DP_COMPARE_CHAR;
                end
            end
            
            DP_UPDATE: begin
                if (w >= num_words) begin
                    next_state = DP_LOOP;
                end else begin
                    next_state = DP_CHECK_WORD;
                end
            end
            
            BACKTRACK: begin
                if (pos == 5'd0) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = BACKTRACK;
                end
            end
            
            OUTPUT: begin
                if (output_ptr >= stack_ptr) begin
                    next_state = DONE;
                end else begin
                    next_state = OUTPUT;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule