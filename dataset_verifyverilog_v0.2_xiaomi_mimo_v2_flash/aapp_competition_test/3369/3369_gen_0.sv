module triple_correlation_detector (
    input [15:0][3:0] seq,
    output reg found,
    output reg [3:0] a,
    output reg [3:0] b,
    output reg [3:0] c,
    output reg [2:0] n,
    output reg [2:0] m
);

    // Combinational block to find the best correlation
    always @(*) begin
        // Internal variables for the search
        integer i, j, k, nn, mm;
        integer idx;
        reg valid_rule1, valid_rule2, valid_rule3;
        reg found_candidate;
        
        // Priority variables
        reg [3:0] best_idx;
        reg [2:0] best_n_val, best_m_val;
        reg [3:0] best_a_val, best_b_val, best_c_val;
        
        // Candidate variables
        reg [3:0] curr_idx;
        
        // Initialize outputs to default (not found)
        found = 0;
        a = 0; b = 0; c = 0; n = 0; m = 0;
        
        // Initialize best trackers to max values
        best_idx = 15;
        best_n_val = 7;
        best_m_val = 7;
        found_candidate = 0;
        
        // Exhaustive search
        for (i = 0; i <= 9; i = i + 1) begin // a
            for (j = 0; j <= 9; j = j + 1) begin // b
                for (k = 0; k <= 9; k = k + 1) begin // c
                    for (nn = 0; nn <= 7; nn = nn + 1) begin
                        for (mm = 0; mm <= 7; mm = mm + 1) begin
                            
                            // Bounds check
                            if (nn + mm >= 16) continue;

                            // Rule 1: a(n)b(m)c
                            valid_rule1 = 1;
                            for (idx = 0; idx <= 15 - nn - mm; idx = idx + 1) begin
                                if (seq[idx] == i && seq[idx + nn] == j && seq[idx + nn + mm] != k) begin
                                    valid_rule1 = 0;
                                    break;
                                end
                            end
                            if (!valid_rule1) continue;

                            // Rule 2: b(m)c requires a(n)
                            valid_rule2 = 1;
                            for (idx = nn; idx <= 15 - mm; idx = idx + 1) begin
                                if (seq[idx] == j && seq[idx + mm] == k && seq[idx - nn] != i) begin
                                    valid_rule2 = 0;
                                    break;
                                end
                            end
                            if (!valid_rule2) continue;

                            // Rule 3: a(n+m)c requires b(n)
                            valid_rule3 = 1;
                            for (idx = 0; idx <= 15 - nn - mm; idx = idx + 1) begin
                                if (seq[idx] == i && seq[idx + nn + mm] == k && seq[idx + nn] != j) begin
                                    valid_rule3 = 0;
                                    break;
                                end
                            end
                            if (!valid_rule3) continue;

                            // If valid, find first occurrence
                            curr_idx = 15;
                            for (idx = 0; idx <= 15 - nn - mm; idx = idx + 1) begin
                                if (seq[idx] == i && seq[idx + nn] == j && seq[idx + nn + mm] == k) begin
                                    curr_idx = idx;
                                    break;
                                end
                            end

                            // Priority update
                            if (curr_idx < best_idx || 
                               (curr_idx == best_idx && nn < best_n_val) || 
                               (curr_idx == best_idx && nn == best_n_val && mm < best_m_val)) begin
                                
                                best_idx = curr_idx;
                                best_n_val = nn;
                                best_m_val = mm;
                                best_a_val = i;
                                best_b_val = j;
                                best_c_val = k;
                                found_candidate = 1;
                            end
                        end
                    end
                end
            end
        end

        if (found_candidate) begin
            found = 1;
            a = best_a_val;
            b = best_b_val;
            c = best_c_val;
            n = best_n_val;
            m = best_m_val;
        end
    end

endmodule