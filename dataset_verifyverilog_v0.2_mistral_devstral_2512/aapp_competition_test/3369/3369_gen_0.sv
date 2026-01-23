module triple_correlation_detector (
    input [15:0][3:0] seq,
    output reg found,
    output reg [3:0] a,
    output reg [3:0] b,
    output reg [3:0] c,
    output reg [2:0] n,
    output reg [2:0] m
);

    integer i, j, k;
    integer idx_a, idx_b, idx_c;
    reg valid_rule1, valid_rule2, valid_rule3;
    reg candidate_valid;
    reg [2:0] best_n, best_m;
    reg [3:0] best_a, best_b, best_c;
    reg [3:0] best_idx;
    reg found_internal;

    always @(*) begin
        found = 0;
        a = 0; b = 0; c = 0; n = 0; m = 0;
        
        best_idx = 15;
        best_n = 7;
        best_m = 7;
        
        for (i = 0; i <= 9; i = i + 1) begin
            for (j = 0; j <= 9; j = j + 1) begin
                for (k = 0; k <= 9; k = k + 1) begin
                    for (int nn = 0; nn <= 7; nn = nn + 1) begin
                        for (int mm = 0; mm <= 7; mm = mm + 1) begin
                            
                            if (nn + mm >= 16) continue;

                            valid_rule1 = 1;
                            for (int idx = 0; idx <= 15 - nn - mm; idx = idx + 1) begin
                                if (seq[idx] == i && seq[idx + nn] == j && seq[idx + nn + mm] != k) begin
                                    valid_rule1 = 0;
                                    break;
                                end
                            end
                            if (!valid_rule1) continue;

                            valid_rule2 = 1;
                            for (int idx = nn; idx <= 15 - mm; idx = idx + 1) begin
                                if (seq[idx] == j && seq[idx + mm] == k && seq[idx - nn] != i) begin
                                    valid_rule2 = 0;
                                    break;
                                end
                            end
                            if (!valid_rule2) continue;

                            valid_rule3 = 1;
                            for (int idx = 0; idx <= 15 - nn - mm; idx = idx + 1) begin
                                if (seq[idx] == i && seq[idx + nn + mm] == k && seq[idx + nn] != j) begin
                                    valid_rule3 = 0;
                                    break;
                                end
                            end
                            if (!valid_rule3) continue;

                            reg [3:0] curr_idx;
                            curr_idx = 15;
                            
                            for (int check_idx = 0; check_idx <= 15 - nn - mm; check_idx = check_idx + 1) begin
                                if (seq[check_idx] == i && seq[check_idx + nn] == j && seq[check_idx + nn + mm] == k) begin
                                    curr_idx = check_idx;
                                    break;
                                end
                            end

                            if (curr_idx < best_idx || 
                               (curr_idx == best_idx && nn < best_n) || 
                               (curr_idx == best_idx && nn == best_n && mm < best_m)) begin
                                
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