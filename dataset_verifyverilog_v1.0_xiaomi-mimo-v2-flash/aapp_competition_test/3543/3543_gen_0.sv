module autocorrect_min_keystrokes (
    input clk,
    input rst_n,
    input start,
    // Dictionary: 16 words, each 16 chars (8 bits per char) + valid flag
    input [15:0] dict_word_addr_valid,  // 16-bit valid flag
    input [127:0] dict_word [0:15],     // 16 words, each 128 bits (16*8)
    input [4:0] dict_len [0:15],        // Length of each dictionary word (0-16)
    // Target word
    input [127:0] target_word,          // 16 chars (128 bits)
    input [4:0] target_len,             // Target length (0-16)
    // Outputs
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] ITERATE_L = 3'd2;
    localparam [2:0] ITERATE_W = 3'd3;
    localparam [2:0] COMPUTE   = 3'd4;
    localparam [2:0] DONE      = 3'd5;
    
    reg [2:0] state, next_state;
    
    // Loop counters
    reg [3:0] l_idx;           // Prefix length L (0-16)
    reg [3:0] w_idx;           // Dictionary word index (0-15)
    reg [7:0] char_idx;        // Character index for comparison
    
    // Temporary storage
    reg [15:0] current_min;    // Current minimum keystrokes
    reg [15:0] current_cost;   // Current computed cost
    reg [4:0] prefix_len;      // Current L being processed
    reg [4:0] w_len;           // Current dictionary word length
    reg match_flag;            // Flag for prefix match
    reg [15:0] temp_result;    // Temporary result holder
    
    // Constants
    localparam [15:0] MAX_COST = 16'hFFFF;
    localparam [15:0] TYPING_ONLY_COST = 16'd16;  // Default max for typing only
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? INIT : IDLE;
            INIT:       next_state = ITERATE_L;
            ITERATE_L:  next_state = ITERATE_W;
            ITERATE_W:  next_state = COMPUTE;
            COMPUTE:    next_state = (l_idx >= target_len && w_idx >= 15) ? DONE : 
                                     (w_idx >= 15 ? ITERATE_L : ITERATE_W);
            DONE:       next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end
    
    // Main sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            current_min <= TYPING_ONLY_COST;
            current_cost <= 16'd0;
            l_idx <= 4'd0;
            w_idx <= 4'd0;
            prefix_len <= 5'd0;
            w_len <= 5'd0;
            match_flag <= 1'b0;
            temp_result <= 16'd0;
            char_idx <= 8'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    // Clear done when idle
                    done <= 1'b0;
                end
                
                INIT: begin
                    // Initialize minimum cost to typing only (len(T))
                    current_min <= target_len;
                    l_idx <= 4'd0;
                    w_idx <= 4'd0;
                    char_idx <= 8'd0;
                end
                
                ITERATE_L: begin
                    // Move to next prefix length
                    if (l_idx <= target_len) begin
                        l_idx <= l_idx + 4'd1;
                        w_idx <= 4'd0;  // Reset word index for new L
                    end
                end
                
                ITERATE_W: begin
                    // Check next dictionary word
                    if (w_idx <= 15) begin
                        w_idx <= w_idx + 4'd1;
                        char_idx <= 8'd0;
                        match_flag <= 1'b0;
                        prefix_len <= l_idx;
                        w_len <= dict_len[w_idx];
                    end
                end
                
                COMPUTE: begin
                    // Check if this dictionary word matches prefix of target
                    if (w_idx <= 15 && dict_word_addr_valid[w_idx]) begin
                        // Check prefix match
                        if (char_idx < l_idx && l_idx > 0) begin
                            // Compare character by character
                            if (dict_word[w_idx][char_idx*8 +: 8] == target_word[char_idx*8 +: 8]) begin
                                if (char_idx == l_idx - 1) begin
                                    match_flag <= 1'b1;
                                end
                            end
                        end
                        
                        // If matched, compute cost
                        if (match_flag || (l_idx == 0 && dict_word_addr_valid[w_idx])) begin
                            // Cost formula: len(T) + 1 + len(W) - 2*L
                            // For l_idx=0, we consider typing without prefix
                            if (l_idx == 0) begin
                                // No prefix, just check if typing word W is better
                                current_cost <= dict_len[w_idx] + 1;  // Just tab to complete
                            end else begin
                                current_cost <= target_len + 1 + w_len - (l_idx << 1);
                            end
                            
                            // Update minimum if this cost is better
                            if (current_cost < current_min) begin
                                current_min <= current_cost;
                            end
                        end
                        
                        // Increment char_idx for next iteration
                        if (char_idx < 16) begin
                            char_idx <= char_idx + 8'd1;
                        end
                    end
                    
                    // Increment word index for next iteration
                    if (w_idx < 15) begin
                        w_idx <= w_idx + 4'd1;
                    end
                end
                
                DONE: begin
                    // Final result: minimum of current_min and typing only
                    if (current_min < target_len) begin
                        result <= current_min;
                    end else begin
                        result <= target_len;
                    end
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule