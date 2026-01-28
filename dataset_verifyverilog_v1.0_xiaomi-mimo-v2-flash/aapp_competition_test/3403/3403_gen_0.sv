module search_steps (
    input clk,
    input rst_n,
    input load_db,
    input [3:0] db_word_idx,
    input [79:0] db_word_in,
    input search_start,
    input [79:0] query_word,
    output reg [15:0] result,
    output reg done
);

    // Parameters
    localparam [3:0] MAX_WORDS = 4'd16;
    localparam [3:0] MAX_LEN = 4'd16;
    localparam [2:0] CHAR_BITS = 3'd5;
    localparam [15:0] MAX_CYCLES = 16'd1000;

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPARE_CHAR = 3'd1;
    localparam [2:0] NEXT_WORD = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Memory for database words
    reg [79:0] db_mem [0:15];

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] result_reg;
    reg [3:0] idx_cnt;          // Database word index (0-15)
    reg [3:0] char_idx;         // Character position (0-15)
    reg [15:0] cycle_cnt;       // Cycle counter for timeout
    reg exact_match;            // Flag for exact match

    // Combinational logic for character extraction
    wire [4:0] char_q;
    wire [4:0] char_d;
    wire [3:0] query_len;       // Calculated query length (simplified)
    wire [3:0] db_len;          // Calculated db word length (simplified)

    // Extract characters: char_idx * 5 = char_idx << 2 + char_idx
    // query_word[char_idx*5 +: 5]
    assign char_q = query_word[{char_idx, 2'b00} +: 5];
    assign char_d = db_mem[idx_cnt][{char_idx, 2'b00} +: 5];

    // Length detection (simplified: check if non-zero, assume max 16)
    // For this algorithm, we treat end-of-word as mismatch or idx >= 16
    // The problem states: "Count until mismatch or end of either word"
    // "End of word" implies null terminator or max length.
    // Since we have fixed 16 chars, we compare up to 16.
    // Exact match check: if char_idx == 16 (full comparison) or query exhausted
    // We'll assume "query exhausted" means we've compared all 16 chars.

    // FSM State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_reg <= 16'd0;
            idx_cnt <= 4'd0;
            char_idx <= 4'd0;
            cycle_cnt <= 16'd0;
            exact_match <= 1'b0;
            done <= 1'b0;
            result <= 16'd0;
        end else begin
            // Default assignments
            done <= 1'b0;
            result <= result_reg;

            case (state)
                IDLE: begin
                    if (search_start) begin
                        state <= COMPARE_CHAR;
                        result_reg <= 16'd0;   // Reset result
                        idx_cnt <= 4'd0;        // Start at first word
                        char_idx <= 4'd0;       // Start at first char
                        cycle_cnt <= 16'd0;
                        exact_match <= 1'b0;
                    end
                end

                COMPARE_CHAR: begin
                    // Check for timeout
                    if (cycle_cnt >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end else begin
                        cycle_cnt <= cycle_cnt + 16'd1;

                        // Character Comparison Logic
                        // If char_idx >= 16 (end of word) or mismatch
                        if (char_idx >= MAX_LEN) begin
                            // End of word reached without mismatch (full 16 chars matched)
                            exact_match <= 1'b1;
                            // Add LCP (16) to result
                            result_reg <= result_reg + 16'd1 + 16'd16; // +1 for word comp, +16 for LCP
                            state <= DONE_STATE;
                        end else if (char_q != char_d) begin
                            // Mismatch found
                            // Add 1 (word comparison) + char_idx (LCP length) to result
                            // Note: char_idx is the count of matched chars before mismatch
                            result_reg <= result_reg + 16'd1 + {12'd0, char_idx};
                            state <= NEXT_WORD;
                        end else begin
                            // Match found, move to next character
                            // Do NOT update result yet (wait for mismatch or end)
                            char_idx <= char_idx + 4'd1;
                            state <= COMPARE_CHAR;
                        end
                    end
                end

                NEXT_WORD: begin
                    // Check if exact match was found (handled in COMPARE_CHAR logic if it was exact)
                    // Actually, exact match logic was integrated into COMPARE_CHAR for simplicity.
                    // If we are here, it was a mismatch.
                    
                    // Advance word index
                    idx_cnt <= idx_cnt + 4'd1;
                    char_idx <= 4'd0;
                    
                    // Check if we have reached the end of the database
                    if (idx_cnt == MAX_WORDS - 4'd1) begin
                        // Last word finished, word not found
                        state <= DONE_STATE;
                    end else begin
                        // Continue to next word
                        state <= COMPARE_CHAR;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    // Hold result and done high until next reset or search_start (though start resets result)
                    state <= IDLE; // Return to IDLE after one cycle of done
                end

                default: state <= IDLE;
            endcase

            // Database Loading Logic (Can happen anytime, independent of FSM)
            if (load_db) begin
                db_mem[db_word_idx] <= db_word_in;
            end
        end
    end

endmodule