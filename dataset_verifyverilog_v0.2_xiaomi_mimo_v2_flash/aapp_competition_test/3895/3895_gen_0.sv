module function_decomposer(
    input [2:0] n,
    input [2:0] f_1, f_2, f_3, f_4, f_5, f_6, f_7, f_8,
    output valid,
    output [2:0] m,
    output [2:0] g_1, g_2, g_3, g_4, g_5, g_6, g_7, g_8,
    output [2:0] h_1, h_2, h_3, h_4, h_5, h_6, h_7, h_8
);

    // Internal array representation of f (1-indexed logic, 0-indexed storage)
    wire [2:0] f [1:8];
    assign f[1] = f_1;
    assign f[2] = f_2;
    assign f[3] = f_3;
    assign f[4] = f_4;
    assign f[5] = f_5;
    assign f[6] = f_6;
    assign f[7] = f_7;
    assign f[8] = f_8;

    // 1. Check Idempotency
    // f is idempotent if f[f[i]] == f[i] for all 1 <= i <= n
    wire idempotent_check [1:8];
    wire any_fail;

    genvar i;
    generate
        for (i = 1; i <= 8; i = i + 1) begin : idempotency_loop
            // Only check if i is within range [1, n]
            // f[i] is a value 1-8. We access f[f[i]].
            // Since input f_j are 1-8, we can use them directly as indices.
            // If f[i] is 0 or > 8, it is invalid input, but problem states 1-8.
            assign idempotent_check[i] = (i <= n) ? (f[f[i]] == f[i]) : 1'b1;
        end
    endgenerate

    assign any_fail = !idempotent_check[1] | !idempotent_check[2] | !idempotent_check[3] | !idempotent_check[4] |
                      !idempotent_check[5] | !idempotent_check[6] | !idempotent_check[7] | !idempotent_check[8];

    assign valid = !any_fail;

    // 2. Build h (Unique values of f)
    // h should be sorted unique values of f[1...n].
    // Since n <= 8, we can use a sorting network or combinational logic.
    // To keep it robust and synthesizable: extract present values, then sort.
    
    // Extract values present in f[1...n] into a temporary array
    // We need to handle duplicates. Logic: 
    // Iterate 1..8 (values). If value appears in f[1..n], add to list.
    
    wire [2:0] h_calc [1:8];
    wire [2:0] m_calc;
    
    // Helper logic to build unique sorted list h
    // This block assumes valid == 1 (idempotent), otherwise output is don't care.
    
    // We use a simple loop to check which values 1..8 exist in f
    // Then pack them into h_calc.
    
    // However, we need sorted order. Since domain is [1..8], checking 1..8 in order gives sorted list.
    // BUT we need to map f[i] to index in this list (1-indexed).
    // If we just check 1..8, h = [1, 2, 3...] but what if f maps to [5, 5, 5]? h should be [5].
    
    // Correct approach for h:
    // Iterate value v from 1 to 8.
    // Check if v appears in f[1..n].
    // If yes, add to list.
    
    wire present [1:8];
    generate
        for (i = 1; i <= 8; i = i + 1) begin : presence_check
            // Check if value 'i' is in f[1..n]
            wire found;
            assign found = (n >= 1 && f_1 == i) || (n >= 2 && f_2 == i) ||
                           (n >= 3 && f_3 == i) || (n >= 4 && f_4 == i) ||
                           (n >= 5 && f_5 == i) || (n >= 6 && f_6 == i) ||
                           (n >= 7 && f_7 == i) || (n >= 8 && f_8 == i);
            assign present[i] = found;
        end
    endgenerate

    // Build h_calc. We need to fill gaps.
    // If present[1] is true, h_calc[1] = 1. Else if present[2] true, h_calc[1] = 2, etc.
    // This is a priority encoder style logic.
    
    // Count m (size of h)
    assign m_calc = (present[1]?1:0) + (present[2]?1:0) + (present[3]?1:0) + (present[4]?1:0) +
                    (present[5]?1:0) + (present[6]?1:0) + (present[7]?1:0) + (present[8]?1:0);

    // Assign m output
    assign m = m_calc;

    // Fill h_calc array based on sorted presence
    // We need to determine h_calc[j] for j=1..8.
    // We use if-else chain for priority encoding.
    
    assign h_calc[1] = (present[1]) ? 3'd1 : 
                       (present[2]) ? 3'd2 :
                       (present[3]) ? 3'd3 :
                       (present[4]) ? 3'd4 :
                       (present[5]) ? 3'd5 :
                       (present[6]) ? 3'd6 :
                       (present[7]) ? 3'd7 : 3'd8;
    
    // For h_calc[2], we skip the first found value
    // Complex combinational logic to skip found values
    
    wire [2:0] second_val;
    assign second_val = (present[1] && (present[2]||present[3]||present[4]||present[5]||present[6]||present[7]||present[8])) ? 3'd2 :
                        (!present[1] && present[2]) ? 3'd2 :
                        (present[3]) ? 3'd3 : 
                        (present[4]) ? 3'd4 :
                        (present[5]) ? 3'd5 :
                        (present[6]) ? 3'd6 :
                        (present[7]) ? 3'd7 : 3'd8;
    // Wait, the logic above is messy for arbitrary skip. 
    // Let's use a more systematic calculation.
    
    // Since we can't use loops inside always_comb easily for indices without generating separate logic,
    // we can use a bit-wise reduction or nested conditions.
    // To simplify for the LLM output: We will define h_calc explicitly using conditions.
    // We need to map the j-th present value to h_calc[j].
    
    // Define array to hold sorted h values
    // Using explicit wires for the 8 positions based on sorted logic
    
    // Position 1: The smallest present value
    wire [2:0] h1_val;
    assign h1_val = present[1] ? 3'd1 : present[2] ? 3'd2 : present[3] ? 3'd3 : present[4] ? 3'd4 :
                    present[5] ? 3'd5 : present[6] ? 3'd6 : present[7] ? 3'd7 : present[8] ? 3'd8 : 3'd0;

    // Position 2: The smallest present value > h1_val
    wire [2:0] h2_val;
    assign h2_val = (present[2] && h1_val < 3'd2) ? 3'd2 :
                    (present[3] && h1_val < 3'd3) ? 3'd3 :
                    (present[4] && h1_val < 3'd4) ? 3'd4 :
                    (present[5] && h1_val < 3'd5) ? 3'd5 :
                    (present[6] && h1_val < 3'd6) ? 3'd6 :
                    (present[7] && h1_val < 3'd7) ? 3'd7 :
                    (present[8] && h1_val < 3'd8) ? 3'd8 : 3'd0;
    // Correction for h2 logic: need to check strictly greater than previous
    // And strictly smaller than next candidates.
    // Actually, simpler: Just find the first present value greater than h1_val
    wire [2:0] h2_calc;
    assign h2_calc = (present[2] && 3'd2 > h1_val) ? 3'd2 :
                     (present[3] && 3'd3 > h1_val) ? 3'd3 :
                     (present[4] && 3'd4 > h1_val) ? 3'd4 :
                     (present[5] && 3'd5 > h1_val) ? 3'd5 :
                     (present[6] && 3'd6 > h1_val) ? 3'd6 :
                     (present[7] && 3'd7 > h1_val) ? 3'd7 :
                     (present[8] && 3'd8 > h1_val) ? 3'd8 : 3'd0;

    // Position 3
    wire [2:0] h3_calc;
    assign h3_calc = (present[3] && 3'd3 > h2_calc && 3'd3 > h1_val) ? 3'd3 :
                     (present[4] && 3'd4 > h2_calc && 3'd4 > h1_val) ? 3'd4 :
                     (present[5] && 3'd5 > h2_calc && 3'd5 > h1_val) ? 3'd5 :
                     (present[6] && 3'd6 > h2_calc && 3'd6 > h1_val) ? 3'd6 :
                     (present[7] && 3'd7 > h2_calc && 3'd7 > h1_val) ? 3'd7 :
                     (present[8] && 3'd8 > h2_calc && 3'd8 > h1_val) ? 3'd8 : 3'd0;
    // Note: h2_calc already > h1_val. We just need > h2_calc (assuming h2_calc is valid).
    // If h2_calc is 0 (meaning no second value), we return 0.
    // So condition: value > max(h1_val, h2_calc)
    // But h2_calc is derived from h1_val, so if h2_calc is valid, it is > h1_val.
    
    wire [2:0] h3_calc_v2;
    assign h3_calc_v2 = (present[3] && 3'd3 > h2_calc && h2_calc != 0) ? 3'd3 :
                        (present[4] && 3'd4 > h2_calc && h2_calc != 0) ? 3'd4 :
                        (present[5] && 3'd5 > h2_calc && h2_calc != 0) ? 3'd5 :
                        (present[6] && 3'd6 > h2_calc && h2_calc != 0) ? 3'd6 :
                        (present[7] && 3'd7 > h2_calc && h2_calc != 0) ? 3'd7 :
                        (present[8] && 3'd8 > h2_calc && h2_calc != 0) ? 3'd8 : 3'd0;

    // Position 4
    wire [2:0] h4_calc;
    assign h4_calc = (present[4] && 3'd4 > h3_calc_v2 && h3_calc_v2 != 0) ? 3'd4 :
                     (present[5] && 3'd5 > h3_calc_v2 && h3_calc_v2 != 0) ? 3'd5 :
                     (present[6] && 3'd6 > h3_calc_v2 && h3_calc_v2 != 0) ? 3'd6 :
                     (present[7] && 3'd7 > h3_calc_v2 && h3_calc_v2 != 0) ? 3'd7 :
                     (present[8] && 3'd8 > h3_calc_v2 && h3_calc_v2 != 0) ? 3'd8 : 3'd0;

    // Position 5
    wire [2:0] h5_calc;
    assign h5_calc = (present[5] && 3'd5 > h4_calc && h4_calc != 0) ? 3'd5 :
                     (present[6] && 3'd6 > h4_calc && h4_calc != 0) ? 3'd6 :
                     (present[7] && 3'd7 > h4_calc && h4_calc != 0) ? 3'd7 :
                     (present[8] && 3'd8 > h4_calc && h4_calc != 0) ? 3'd8 : 3'd0;

    // Position 6
    wire [2:0] h6_calc;
    assign h6_calc = (present[6] && 3'd6 > h5_calc && h5_calc != 0) ? 3'd6 :
                     (present[7] && 3'd7 > h5_calc && h5_calc != 0) ? 3'd7 :
                     (present[8] && 3'd8 > h5_calc && h5_calc != 0) ? 3'd8 : 3'd0;

    // Position 7
    wire [2:0] h7_calc;
    assign h7_calc = (present[7] && 3'd7 > h6_calc && h6_calc != 0) ? 3'd7 :
                     (present[8] && 3'd8 > h6_calc && h6_calc != 0) ? 3'd8 : 3'd0;

    // Position 8
    wire [2:0] h8_calc;
    assign h8_calc = (present[8] && 3'd8 > h7_calc && h7_calc != 0) ? 3'd8 : 3'd0;

    // Now assign to h_calc array for indexing
    assign h_calc[1] = h1_val;
    assign h_calc[2] = h2_calc;
    assign h_calc[3] = h3_calc_v2;
    assign h_calc[4] = h4_calc;
    assign h_calc[5] = h5_calc;
    assign h_calc[6] = h6_calc;
    assign h_calc[7] = h7_calc;
    assign h_calc[8] = h8_calc;

    // Assign Outputs h_1 ... h_8
    assign h_1 = h_calc[1];
    assign h_2 = h_calc[2];
    assign h_3 = h_calc[3];
    assign h_4 = h_calc[4];
    assign h_5 = h_calc[5];
    assign h_6 = h_calc[6];
    assign h_7 = h_calc[7];
    assign h_8 = h_calc[8];

    // 3. Build g
    // g[i] = index of f[i] in h (1-indexed)
    // Map f[i] -> j such that h[j] == f[i]
    
    wire [2:0] g_internal [1:8];
    
    // Function to find index of value v in h_calc
    // Since h is sorted and unique, we can match.
    
    function [2:0] find_index;
        input [2:0] val;
        input [2:0] h [1:8];
        integer k;
        begin
            find_index = 0;
            for (k = 1; k <= 8; k = k + 1) begin
                if (h[k] == val) begin
                    find_index = k;
                end
            end
        end
    endfunction

    // Since we must be synthesizable and combinational, we use explicit logic for g.
    // g[i] is 1 if f[i] == h[1], 2 if f[i] == h[2], etc.
    
    generate
        for (i = 1; i <= 8; i = i + 1) begin : g_gen
            // If i <= n, calculate g. Else 0.
            // We compare f[i] with all h_calc[j] values.
            wire [2:0] val;
            assign val = f[i];
            
            // Logic: if val == h_calc[1], g=1. Elif val == h_calc[2], g=2...
            // Note: h_calc might be 0 (invalid), but if valid=1, only first m are valid non-zero.
            // Since f values are always 1-8, we can just check equality.
            
            assign g_internal[i] = 
                (val == h_calc[1]) ? 3'd1 :
                (val == h_calc[2]) ? 3'd2 :
                (val == h_calc[3]) ? 3'd3 :
                (val == h_calc[4]) ? 3'd4 :
                (val == h_calc[5]) ? 3'd5 :
                (val == h_calc[6]) ? 3'd6 :
                (val == h_calc[7]) ? 3'd7 :
                (val == h_calc[8]) ? 3'd8 : 3'd0;
                
            // Assign to output ports g_1...
            // If invalid or i > n, output 0 (as requested)
            case(i)
                1: assign g_1 = (valid && i <= n) ? g_internal[i] : 0;
                2: assign g_2 = (valid && i <= n) ? g_internal[i] : 0;
                3: assign g_3 = (valid && i <= n) ? g_internal[i] : 0;
                4: assign g_4 = (valid && i <= n) ? g_internal[i] : 0;
                5: assign g_5 = (valid && i <= n) ? g_internal[i] : 0;
                6: assign g_6 = (valid && i <= n) ? g_internal[i] : 0;
                7: assign g_7 = (valid && i <= n) ? g_internal[i] : 0;
                8: assign g_8 = (valid && i <= n) ? g_internal[i] : 0;
            endcase
        end
    endgenerate

endmodule
