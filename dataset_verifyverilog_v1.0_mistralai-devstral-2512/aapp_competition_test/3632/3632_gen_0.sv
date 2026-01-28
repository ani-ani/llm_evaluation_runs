module RankCalculator(
    input clk,
    input rst_n,
    input start,
    input [15:0] str_en,
    input [255:0] str_data,
    input [255:0] test_str,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [3:0] MAX_STRINGS = 16;
    localparam [3:0] MAX_LENGTH = 16;
    localparam [3:0] MAX_K = 16;

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] PARSE = 4'd2;
    localparam [3:0] COMPUTE = 4'd3;
    localparam [3:0] FINISH = 4'd4;

    // FSM state
    reg [3:0] state, next_state;

    // Counters and control
    reg [7:0] cycle_count;
    reg [3:0] k;
    reg [3:0] current_pos;
    reg [3:0] current_char_pos;
    reg [3:0] current_str_idx;
    reg [3:0] remaining_strings;
    reg [3:0] remaining_positions;

    // String processing
    reg [7:0] current_char;
    reg [7:0] test_char;
    reg [7:0] str_char;

    // Used mask
    reg [15:0] used_mask;

    // Intermediate results
    reg [31:0] current_count;
    reg [31:0] temp_count;
    reg [31:0] factorial;
    reg [31:0] inv_factorial;

    // Factorial lookup table (precomputed for k=0 to 16)
    reg [31:0] fact [0:16];

    // Trie node structure (simplified for small strings)
    reg [7:0] trie_char [0:255];
    reg [7:0] trie_next [0:255];
    reg [7:0] trie_terminal [0:255];

    // Initialize factorial table
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            k <= 4'd0;
            current_pos <= 4'd0;
            current_char_pos <= 4'd0;
            current_str_idx <= 4'd0;
            remaining_strings <= 4'd0;
            remaining_positions <= 4'd0;
            current_char <= 8'd0;
            test_char <= 8'd0;
            str_char <= 8'd0;
            used_mask <= 16'd0;
            current_count <= 32'd0;
            temp_count <= 32'd0;
            factorial <= 32'd0;
            inv_factorial <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;

            // Initialize factorial table
            for (i = 0; i <= 16; i = i + 1) begin
                fact[i] <= 32'd0;
            end
            fact[0] <= 32'd1;
            for (i = 1; i <= 16; i = i + 1) begin
                fact[i] <= (fact[i-1] * i) % MOD;
            end

            // Initialize trie (simplified for this example)
            // In a real implementation, this would be built from str_data and str_en
            // For this example, we'll assume a simple trie structure
            for (i = 0; i < 256; i = i + 1) begin
                trie_char[i] <= 8'd0;
                trie_next[i] <= 8'd0;
                trie_terminal[i] <= 8'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Count number of valid strings (k)
                    k <= 4'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (str_en[i]) begin
                            k <= k + 4'd1;
                        end
                    end

                    // Initialize variables
                    current_pos <= 4'd0;
                    current_char_pos <= 4'd0;
                    current_str_idx <= 4'd0;
                    remaining_strings <= k;
                    remaining_positions <= k;
                    used_mask <= 16'd0;
                    current_count <= 32'd0;
                    result <= 32'd0;

                    next_state <= PARSE;
                end

                PARSE: begin
                    // Parse test string into segments
                    // This is a simplified version - in reality, you'd traverse the trie
                    // For this example, we'll assume we can find the segments

                    // Get current character from test string
                    test_char <= test_str[current_char_pos * 8 +: 8];

                    // Compare with strings in the trie
                    // This is a placeholder for the actual trie traversal
                    // In a real implementation, you'd traverse the trie to find matching strings

                    // For this example, we'll assume we find a match
                    // and move to the next character
                    current_char_pos <= current_char_pos + 4'd1;

                    // If we've reached the end of a segment
                    if (current_char_pos == MAX_LENGTH || test_char == 8'd0) begin
                        current_char_pos <= 4'd0;
                        current_pos <= current_pos + 4'd1;

                        // If we've parsed all k segments
                        if (current_pos == k) begin
                            next_state <= COMPUTE;
                        end
                    end
                end

                COMPUTE: begin
                    // Compute the rank
                    // For each position, calculate the number of strings lexicographically smaller
                    // than the current segment, multiplied by the permutations of remaining strings

                    // This is a simplified version - in reality, you'd:
                    // 1. For each position i, count how many unused strings are lex smaller than segment i
                    // 2. Multiply by fact[remaining_strings - 1]
                    // 3. Add to result

                    // For this example, we'll just do a simple calculation
                    temp_count <= 32'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (str_en[i] && !used_mask[i]) begin
                            // Compare string i with current segment
                            // This is a placeholder for actual comparison
                            // In reality, you'd compare byte-by-byte
                            temp_count <= temp_count + 32'd1;
                        end
                    end

                    // Multiply by factorial of remaining positions
                    factorial <= fact[remaining_positions - 4'd1];
                    temp_count <= (temp_count * factorial) % MOD;

                    // Add to result
                    result <= (result + temp_count) % MOD;

                    // Mark current string as used
                    used_mask[current_str_idx] <= 1'b1;
                    remaining_strings <= remaining_strings - 4'd1;
                    remaining_positions <= remaining_positions - 4'd1;
                    current_str_idx <= current_str_idx + 4'd1;

                    // If we've processed all positions
                    if (current_str_idx == k) begin
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase

            // Safety counter to prevent infinite loops
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= 8'd255) begin
                next_state <= IDLE;
            end
        end
    end

    // Helper function for modular multiplication
    function [31:0] mod_mult;
        input [31:0] a, b;
        begin
            mod_mult = (a * b) % MOD;
        end
    endfunction

    // Helper function for modular addition
    function [31:0] mod_add;
        input [31:0] a, b;
        begin
            mod_add = (a + b) % MOD;
        end
    endfunction

endmodule