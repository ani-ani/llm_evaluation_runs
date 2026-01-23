module triple_correlation_detector (
    input [15:0][3:0] seq,
    output reg found,
    output reg [3:0] a,
    output reg [3:0] b,
    output reg [3:0] c,
    output reg [2:0] n,
    output reg [2:0] m
);

    // This module searches for triple correlations in a 16-digit sequence.
    // The input 'seq' is an array of 16 4-bit digits.
    // It implements the three conditions:
    // 1. a(n)b(m)c: if a is at i and b is at i+n, then c must be at i+n+m.
    // 2. b(m)c requires a(n)
    // 3. a(n+m)c requires b(n)
    // Minimum occurrences: ceil(16/40)+1 = 1 time.

    integer i, j, k;
    reg valid_rule1, valid_rule2, valid_rule3;
    reg candidate_valid;
    reg [2:0] best_n, best_m;
    reg [3:0] best_a, best_b, best_c;
    reg [3:0] best_idx; // Stores the starting index for priority
    reg found_internal;

    always @(*) begin
        // Initialize outputs to default (not found)
        found = 0;
        a = 0; b = 0; c = 0; n = 0; m = 0;

        best_idx = 15; // Start with max index (worst case)
        best_n = 7;
        best_m = 7;

        // Exhaustive search over all possible a, b, c, n, m
        for (i = 0; i <= 9; i = i + 1) begin // a
            for (j = 0; j <= 9; j = j + 1) begin // b
                for (k = 0; k <= 9; k = k + 1) begin // c
                    for (integer nn = 0; nn <= 7; nn = nn + 1) begin
                        for (integer mm = 0; mm <= 7; mm = mm + 1) begin

                            // Skip if n+m >= 16 (impossible in sequence of 16)
                            if (nn + mm >= 16) continue;

                            // Check Correlation Rules

                            // Rule 1: a(n)b(m)c
                            valid_rule1 = 1;
                            for (integer idx = 0; idx <= 15 - nn - mm; idx = idx + 1) begin
                                if (seq[idx] == i && seq[idx + nn] == j && seq[idx + nn + mm] != k) begin
                                    valid_rule1 = 0;
                                    break;
                                end
                            end
                            if (!valid_rule1) continue;

                            // Rule 2: b(m)c requires a(n)
                            valid_rule2 = 1;
                            for (integer idx = nn; idx <= 15 - mm; idx = idx + 1) begin
                                if (seq[idx] == j && seq[idx + mm] == k && seq[idx - nn] != i) begin
                                    valid_rule2 = 0;
                                    break;
                                end
                            end
                            if (!valid_rule2) continue;

                            // Rule 3: a(n+m)c requires b(n)
                            valid_rule3 = 1;
                            for (integer idx = 0; idx <= 15 - nn - mm; idx = idx + 1) begin
                                if (seq[idx] == i && seq[idx + nn + mm] == k && seq[idx + nn] != j) begin
                                    valid_rule3 = 0;
                                    break;
                                end
                            end
                            if (!valid_rule3) continue;

                            // If we are here, we found a valid correlation.
                            // Now determine if it's better than the current best.
                            // Criteria: Earliest start index, then smaller n, then smaller m.

                            // Find earliest occurrence index for this candidate
                            // (We can just scan from 0)
                            reg [3:0] curr_idx;
                            curr_idx = 15; // Default to high

                            // Find first occurrence of 'a' that starts a valid sequence
                            for (integer check_idx = 0; check_idx <= 15 - nn - mm; check_idx = check_idx + 1) begin
                                if (seq[check_idx] == i && seq[check_idx + nn] == j && seq[check_idx + nn + mm] == k) begin
                                    curr_idx = check_idx;
                                    break;
                                end
                            end

                            // Comparison Logic for Priority
                            if (curr_idx < best_idx || (curr_idx == best_idx && nn < best_n) || (curr_idx == best_idx && nn == best_n && mm < best_m)) begin

                                best_idx = curr_idx;
                                best_n = nn;
                                best_m = mm;
                                best_a = i;
                                best_b = j;
                                best_c = k;
                                found_internal = 1;
                            end
                        end
                    end
                end
            end
        end

        if (found_internal) begin
            found = 1;
            a = best_a;
            b = best_b;
            c = best_c;
            n = best_n;
            m = best_m;
        end
    end

endmodule