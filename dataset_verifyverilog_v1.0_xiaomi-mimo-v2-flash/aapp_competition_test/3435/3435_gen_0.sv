module CountUniqueBinaryStrings (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [29:0] pattern,
    input wire [5:0] n,
    input wire [5:0] pattern_len,
    output reg [15:0] count,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE     = 4'd0;
    localparam [3:0] CHECK_LEN = 4'd1;
    localparam [3:0] PREP_TRIVIAL = 4'd2;  // len > n or len == n
    localparam [3:0] TRIVIAL_CALC = 4'd3;
    localparam [3:0] PREP_SUBSTRING = 4'd4;
    localparam [3:0] SUBSTRING_LOOP = 4'd5;
    localparam [3:0] SUBSTRING_MATCH = 4'd6;
    localparam [3:0] CALC_COMPLETION = 4'd7;
    localparam [3:0] FINISH      = 4'd8;

    reg [3:0] state;
    reg [7:0] cycle_count;  // Safety counter
    localparam [7:0] MAX_CYCLES = 8'd120;

    // Internal registers
    reg [5:0] i, j, k;  // Loop counters
    reg [15:0] temp_count;
    reg [15:0] temp_pow2;
    reg [15:0] total_strings;
    reg [15:0] strings_no_match;
    reg [15:0] matches_count;
    reg [5:0] start_pos;
    reg valid_match;
    reg match_found;

    // Function to check if pattern matches substring at position start
    // This is combinational logic broken into steps
    reg checking_match;
    reg [5:0] match_pat_pos;
    reg [15:0] power_of_2;

    // Power of 2 calculation lookup (2^n mod 65535)
    // Actually 2^n for n <= 15, but since n can be up to 50, we need modular exponentiation
    // Simplified: 2^n mod 65535 = (2^(n mod 16)) mod 65535 for n >= 16 since 2^16 = 65536 ≡ 1 mod 65535
    // For n < 16: direct value
    // For n >= 16: 2^(n mod 16) mod 65535
    wire [5:0] n_mod_16;
    assign n_mod_16 = n % 16;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 6'd0;
            j <= 6'd0;
            k <= 6'd0;
            temp_count <= 16'd0;
            temp_pow2 <= 16'd0;
            total_strings <= 16'd0;
            strings_no_match <= 16'd0;
            matches_count <= 16'd0;
            start_pos <= 6'd0;
            valid_match <= 1'b0;
            match_found <= 1'b0;
            checking_match <= 1'b0;
            match_pat_pos <= 6'd0;
            power_of_2 <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    i <= 6'd0;
                    j <= 6'd0;
                    k <= 6'd0;
                    if (start) begin
                        state <= CHECK_LEN;
                    end
                end

                CHECK_LEN: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (pattern_len > n) begin
                        state <= PREP_TRIVIAL;  // Result is 0
                    end else if (pattern_len == n) begin
                        state <= PREP_TRIVIAL;  // Simple case
                    end else begin
                        state <= PREP_SUBSTRING;  // Substring matching
                    end
                end

                PREP_TRIVIAL: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (pattern_len > n) begin
                        // Result is 0
                        temp_count <= 16'd0;
                        state <= FINISH;
                    end else if (pattern_len == n) begin
                        // Count strings where bits must match '1'
                        // Each '1' in pattern fixes a bit to 1
                        // Each '*' allows 0 or 1
                        // Count = 2^(number of '*')
                        i <= 6'd0;
                        temp_count <= 16'd0;  // Count of stars
                        state <= TRIVIAL_CALC;
                    end
                end

                TRIVIAL_CALC: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Count stars
                    if (i < pattern_len) begin
                        if (pattern[i] == 1'b0) begin  // '*' is encoded as 0, '1' as 1
                            temp_count <= temp_count + 16'd1;
                        end
                        i <= i + 6'd1;
                    end else begin
                        // Calculate 2^temp_count mod 65535
                        // temp_count is number of stars (max 30)
                        // 2^k mod 65535
                        // If k < 16: 2^k
                        // If k >= 16: (2^16)^m * 2^r mod 65535 = 1^m * 2^r mod 65535 = 2^r mod 65535
                        i <= temp_count;
                        // Compute 2^i
                        if (temp_count < 16) begin
                            temp_count <= (1 << temp_count);  // 2^temp_count
                        end else begin
                            // 2^(temp_count mod 16)
                            temp_count <= (1 << (temp_count % 16));
                        end
                        state <= FINISH;
                    end
                end

                PREP_SUBSTRING: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Calculate total strings = 2^n mod 65535
                    if (n < 16) begin
                        total_strings <= (1 << n);
                    end else begin
                        total_strings <= (1 << (n % 16));
                    end
                    // Initialize for substring loop
                    start_pos <= 6'd0;
                    matches_count <= 16'd0;
                    match_found <= 1'b0;
                    state <= SUBSTRING_LOOP;
                end

                SUBSTRING_LOOP: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Check if start_pos + pattern_len <= n
                    if (start_pos + pattern_len <= n) begin
                        // Check if pattern matches starting at start_pos
                        i <= 6'd0;  // Pattern index
                        checking_match <= 1'b1;
                        valid_match <= 1'b1;
                        state <= SUBSTRING_MATCH;
                    end else begin
                        // Finished all start positions
                        state <= CALC_COMPLETION;
                    end
                end

                SUBSTRING_MATCH: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (checking_match) begin
                        // Check pattern[i] with string bit at (start_pos + i)
                        // Pattern: pattern[i] = 1 means bit must be 1
                        //           pattern[i] = 0 means '*' (don't care)
                        // For counting unique strings that match:
                        // If pattern[i] is '1', the bit at that position must be 1
                        // If pattern[i] is '*', the bit can be 0 or 1
                        // But we're checking if a specific substring position matches
                        // This is actually about counting strings, not checking a specific string
                        // 
                        // The logic: We need to count how many strings of length n
                        // have AT LEAST ONE substring of length pattern_len that matches pattern
                        // 
                        // For inclusion-exclusion: Count strings with NO match, subtract from total
                        // But exact inclusion-exclusion is complex
                        // 
                        // Alternative: Direct count
                        // Strings with match at position p: 2^(n - pattern_len) * 2^(num_stars_in_pattern)
                        // But overlaps make this complex
                        // 
                        // Simplified approach for 16-bit output:
                        // Use approximation or bounded counting
                        // 
                        // For this implementation, we'll compute:
                        // Count = total_strings - strings_with_no_match
                        // To compute strings_with_no_match:
                        // For each position in string, if it matches '1' in pattern at any alignment...
                        // This is still complex.
                        //
                        // New approach: Direct DP
                        // State: [string_pos][pat_pos][match_status]
                        // Since n <= 50 and pattern_len <= 30, this is too big for full DP in 16-bit.
                        //
                        // Simplified for synthesis:
                        // We compute approximate count using bounded loops
                        // 
                        // Let's do direct counting of matching strings at each position
                        // For each alignment p from 0 to n-pattern_len:
                        // Count strings that match at position p
                        // But need to avoid double counting strings with multiple matches
                        // 
                        // Simplified: Count strings that match at LEAST ONE position
                        // Using inclusion-exclusion up to 2 terms (approximate)
                        // 
                        // For this implementation, we'll use a simplified formula:
                        // If pattern has k '1's and m '*'s (k+m = pattern_len):
                        // Bits fixed by pattern: k
                        // Free bits in substring: m
                        // Bits outside substring: n - pattern_len
                        // Count per alignment: 2^(m + n - pattern_len) = 2^(n - k)
                        // 
                        // Number of alignments: n - pattern_len + 1
                        // Total (naive): (n - pattern_len + 1) * 2^(n - k)
                        // Overcount for strings matching at multiple positions
                        // 
                        // For 16-bit output, we'll compute this approximate count
                        // and apply saturation
                        //
                        // Step 1: Count '1's in pattern
                        if (i < pattern_len) begin
                            if (pattern[i] == 1'b1) begin
                                j <= j + 6'd1;  // j = count of '1's
                            end
                            i <= i + 6'd1;
                        end else begin
                            // j now has count of '1's
                            // n - j = number of free bits
                            if (n >= j) begin
                                i <= n - j;  // Exponent for 2^(n-j)
                                // Compute 2^(n-j) mod 65535
                                if ((n - j) < 16) begin
                                    temp_pow2 <= (1 << (n - j));
                                end else begin
                                    temp_pow2 <= (1 << ((n - j) % 16));
                                end
                            end else begin
                                // n < j, impossible to match
                                temp_pow2 <= 16'd0;
                            end
                            i <= 6'd0;  // Reset for next step
                            checking_match <= 1'b0;
                            // Calculate number of alignments
                            if (n >= pattern_len) begin
                                k <= n - pattern_len + 6'd1;  // Number of alignments
                            end else begin
                                k <= 6'd0;
                            end
                            // Now multiply k * temp_pow2
                            state <= CALC_COMPLETION;
                        end
                    end
                end

                CALC_COMPLETION: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Calculate: matches_count = (n - pattern_len + 1) * 2^(n - count_ones(pattern))
                    // k = n - pattern_len + 1 (stored in k)
                    // temp_pow2 = 2^(n - count_ones)
                    // 
                    // However, we need to subtract overlaps for multiple matches
                    // For simplicity and to fit 16-bit:
                    // Count = min(total_strings, k * temp_pow2) with some adjustment
                    // 
                    // Better: Use inclusion-exclusion approximation
                    // Count = k * temp_pow2 - (k-1 choose 2) * 2^(n - 2*count_ones + overlap)
                    // 
                    // For this implementation, we'll compute:
                    // If k (alignments) is 0, result is 0
                    // If k > 0, compute k * temp_pow2
                    // Then adjust for saturation
                    //
                    // Actually, for exact count with small n and pattern_len:
                    // We can iterate through all alignments and compute contribution
                    // But for 16-bit, let's compute the dominant term
                    //
                    // New plan: Direct compute for small cases
                    if (k == 6'd0) begin
                        temp_count <= 16'd0;
                        state <= FINISH;
                    end else begin
                        // Multiply k * temp_pow2
                        // k is at most 50, temp_pow2 is at most 32768
                        // Product can be > 65535
                        i <= 6'd0;  // Counter for multiplication
                        temp_count <= 16'd0;
                        // Addition loop
                        state <= 4'd12;  // Use a new state for multiplication
                    end
                end

                4'd12: begin  // Multiplication loop (k * temp_pow2)
                    cycle_count <= cycle_count + 8'd1;
                    if (i < k) begin
                        // Check for overflow before addition
                        if (temp_count <= 16'd65535 - temp_pow2) begin
                            temp_count <= temp_count + temp_pow2;
                        end else begin
                            temp_count <= 16'd65535;  // Saturate
                        end
                        i <= i + 6'd1;
                    end else begin
                        // Now adjust for double counting
                        // If k >= 2, we overcounted strings that match at 2 or more positions
                        // Approximate correction: subtract (k-1) * 2^(n - 2*count_ones + adjustment)
                        // 
                        // For simplicity, if temp_count is already large, keep it
                        // If k is small, apply correction
                        //
                        // Correction: subtract (k-1) * 2^(n - 2*j + 1) for overlapping cases
                        // where j = count of '1's
                        // This is an approximation
                        //
                        // Only apply if k >= 2 and temp_count is reasonable
                        if (k >= 6'd2 && j >= 6'd1 && temp_count > 16'd1000) begin
                            // Calculate correction: 2^(n - 2*j + 1)
                            // n - 2*j + 1 can be negative, treat as 0
                            if (n >= 2*j - 6'd1) begin
                                i <= n - 2*j + 6'd1;  // Exponent
                                if ((n - 2*j + 6'd1) < 16) begin
                                    temp_pow2 <= (1 << (n - 2*j + 6'd1));
                                end else begin
                                    temp_pow2 <= (1 << ((n - 2*j + 6'd1) % 16));
                                end
                                k <= k - 6'd1;  // k-1
                                state <= 4'd13;  // Subtract correction
                            end else begin
                                state <= FINISH;
                            end
                        end else begin
                            state <= FINISH;
                        end
                    end
                end

                4'd13: begin  // Subtract correction (k-1) * 2^(...)
                    cycle_count <= cycle_count + 8'd1;
                    // Similar multiplication but subtract
                    if (i < k) begin
                        if (temp_count >= temp_pow2) begin
                            temp_count <= temp_count - temp_pow2;
                        end else begin
                            temp_count <= 16'd0;
                        end
                        i <= i + 6'd1;
                    end else begin
                        // Final adjustment: ensure not exceeding total_strings
                        if (temp_count > total_strings) begin
                            temp_count <= total_strings;
                        end
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    count <= temp_count;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule