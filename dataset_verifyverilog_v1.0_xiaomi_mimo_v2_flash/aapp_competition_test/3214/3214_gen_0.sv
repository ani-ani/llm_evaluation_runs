module typo_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] word_count,
    input wire [511:0] words,
    input wire [31:0] word_lengths,
    output reg pair_valid,
    output reg [3:0] word1_idx,
    output reg [3:0] word2_idx,
    output reg done
);

// State definitions
localparam [3:0] S_IDLE       = 4'd0;
localparam [3:0] S_LOAD       = 4'd1;
localparam [3:0] S_LOOP_I     = 4'd2;
localparam [3:0] S_LOOP_J     = 4'd3;
localparam [3:0] S_CHECK      = 4'd4;
localparam [3:0] S_OUTPUT     = 4'd5;
localparam [3:0] S_INCREMENT_J = 4'd6;
localparam [3:0] S_INCREMENT_I = 4'd7;
localparam [3:0] S_DONE       = 4'd8;

reg [3:0] state;
reg [2:0] i, j;
reg [2:0] i_reg, j_reg;
reg [63:0] word1_reg, word2_reg;
reg [3:0] len1_reg, len2_reg;
reg is_similar;

// Cycle counter to prevent infinite loops
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd255;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        pair_valid <= 1'b0;
        word1_idx <= 4'd0;
        word2_idx <= 4'd0;
        done <= 1'b0;
        i <= 3'd0;
        j <= 3'd0;
        i_reg <= 3'd0;
        j_reg <= 3'd0;
        word1_reg <= 64'd0;
        word2_reg <= 64'd0;
        len1_reg <= 4'd0;
        len2_reg <= 4'd0;
        is_similar <= 1'b0;
        cycle_count <= 8'd0;
    end else begin
        cycle_count <= cycle_count + 8'd1;
        
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                pair_valid <= 1'b0;
                cycle_count <= 8'd0;
                if (start) begin
                    state <= S_LOAD;
                end
            end
            
            S_LOAD: begin
                // Extract first word and length
                word1_reg <= words[63:0];
                len1_reg <= word_lengths[3:0];
                i <= 3'd0;
                j <= 3'd1;
                state <= S_LOOP_I;
            end
            
            S_LOOP_I: begin
                if (word_count <= 4'd1) begin
                    state <= S_DONE;
                end else if (i < word_count - 4'd1) begin
                    // Extract current word and length for i
                    word1_reg <= words[i * 64 +: 64];
                    len1_reg <= word_lengths[i * 4 +: 4];
                    j <= i + 4'd1;
                    state <= S_LOOP_J;
                end else begin
                    state <= S_DONE;
                end
            end
            
            S_LOOP_J: begin
                if (j < word_count) begin
                    // Extract current word and length for j
                    word2_reg <= words[j * 64 +: 64];
                    len2_reg <= word_lengths[j * 4 +: 4];
                    state <= S_CHECK;
                end else begin
                    state <= S_INCREMENT_I;
                end
            end
            
            S_CHECK: begin
                // Check similarity (combinational logic)
                is_similar <= 1'b0;
                
                // Delete: len1 = len2 + 1
                if (len1_reg == len2_reg + 4'd1) begin
                    for (integer pos = 0; pos < 8; pos = pos + 1) begin
                        if (pos < len1_reg) begin
                            reg match;
                            match = 1'b1;
                            // Check prefix
                            for (integer k = 0; k < pos; k = k + 1) begin
                                if (word1_reg[k * 8 +: 8] != word2_reg[k * 8 +: 8]) match = 1'b0;
                            end
                            // Check suffix
                            for (integer k = pos; k < len2_reg; k = k + 1) begin
                                if (word1_reg[(k + 1) * 8 +: 8] != word2_reg[k * 8 +: 8]) match = 1'b0;
                            end
                            if (match) is_similar <= 1'b1;
                        end
                    end
                end
                
                // Insert: len2 = len1 + 1
                else if (len2_reg == len1_reg + 4'd1) begin
                    for (integer pos = 0; pos < 8; pos = pos + 1) begin
                        if (pos < len2_reg) begin
                            reg match;
                            match = 1'b1;
                            // Check prefix
                            for (integer k = 0; k < pos; k = k + 1) begin
                                if (word2_reg[k * 8 +: 8] != word1_reg[k * 8 +: 8]) match = 1'b0;
                            end
                            // Check suffix
                            for (integer k = pos; k < len1_reg; k = k + 1) begin
                                if (word2_reg[(k + 1) * 8 +: 8] != word1_reg[k * 8 +: 8]) match = 1'b0;
                            end
                            if (match) is_similar <= 1'b1;
                        end
                    end
                end
                
                // Replace and transpose: len1 == len2
                else if (len1_reg == len2_reg) begin
                    // Replace: exactly one character difference
                    reg [3:0] diff_count;
                    diff_count = 4'd0;
                    for (integer k = 0; k < 8; k = k + 1) begin
                        if (k < len1_reg) begin
                            if (word1_reg[k * 8 +: 8] != word2_reg[k * 8 +: 8]) begin
                                diff_count = diff_count + 4'd1;
                            end
                        end
                    end
                    if (diff_count == 4'd1) is_similar <= 1'b1;
                    
                    // Transpose: one adjacent swap
                    for (integer pos = 0; pos < 8; pos = pos + 1) begin
                        if (pos < len1_reg - 4'd1) begin
                            reg match;
                            match = 1'b1;
                            // Check swapped pair
                            if (word1_reg[pos * 8 +: 8] != word2_reg[(pos + 1) * 8 +: 8]) match = 1'b0;
                            if (word1_reg[(pos + 1) * 8 +: 8] != word2_reg[pos * 8 +: 8]) match = 1'b0;
                            // Check rest
                            for (integer k = 0; k < 8; k = k + 1) begin
                                if (k != pos && k != pos + 1 && k < len1_reg) begin
                                    if (word1_reg[k * 8 +: 8] != word2_reg[k * 8 +: 8]) match = 1'b0;
                                end
                            end
                            if (match) is_similar <= 1'b1;
                        end
                    end
                end
                
                state <= S_OUTPUT;
            end
            
            S_OUTPUT: begin
                if (is_similar) begin
                    pair_valid <= 1'b1;
                    word1_idx <= {1'b0, i};
                    word2_idx <= {1'b0, j};
                end
                state <= S_INCREMENT_J;
            end
            
            S_INCREMENT_J: begin
                pair_valid <= 1'b0;
                j <= j + 4'd1;
                state <= S_LOOP_J;
            end
            
            S_INCREMENT_I: begin
                i <= i + 4'd1;
                state <= S_LOOP_I;
            end
            
            S_DONE: begin
                done <= 1'b1;
                state <= S_IDLE;
            end
            
            default: begin
                state <= S_IDLE;
            end
        endcase
        
        // Safety: return to idle if too many cycles
        if (cycle_count >= MAX_CYCLES) begin
            state <= S_IDLE;
            done <= 1'b1;
        end
    end
end

endmodule