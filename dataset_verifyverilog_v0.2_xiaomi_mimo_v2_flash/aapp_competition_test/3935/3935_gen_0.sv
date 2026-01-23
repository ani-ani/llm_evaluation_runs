module bipartite_set_optimizer (
    input  [15:0] valid_in,
    input  [63:0] numbers_in [0:15],
    output [15:0] remove_mask,
    output [63:0] removed_values [0:15]
);

    // 1. Compute Count Trailing Zeros (ctz) for each valid input
    // ctz 0 means LSB is 1.
    wire [5:0] ctz [0:15];
    wire [15:0] input_valid; // Input validity

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : ctz_gen
            // Priority encoder logic for ctz
            // numbers_in[i] is 64-bit. Find position of first 1 (LSB is index 0).
            // If number is 0, ctz is undefined, but typically inputs are valid non-zero numbers for this problem.
            // We treat 0 as having ctz 63 (all zeros) or just check valid_in.
            // Using a complex logic loop or explicit priority encoder:
            assign ctz[i] = (
                numbers_in[i][0]  ? 6'd0  :
                numbers_in[i][1]  ? 6'd1  :
                numbers_in[i][2]  ? 6'd2  :
                numbers_in[i][3]  ? 6'd3  :
                numbers_in[i][4]  ? 6'd4  :
                numbers_in[i][5]  ? 6'd5  :
                numbers_in[i][6]  ? 6'd6  :
                numbers_in[i][7]  ? 6'd7  :
                numbers_in[i][8]  ? 6'd8  :
                numbers_in[i][9]  ? 6'd9  :
                numbers_in[i][10] ? 6'd10 :
                numbers_in[i][11] ? 6'd11 :
                numbers_in[i][12] ? 6'd12 :
                numbers_in[i][13] ? 6'd13 :
                numbers_in[i][14] ? 6'd14 :
                numbers_in[i][15] ? 6'd15 :
                numbers_in[i][16] ? 6'd16 :
                numbers_in[i][17] ? 6'd17 :
                numbers_in[i][18] ? 6'd18 :
                numbers_in[i][19] ? 6'd19 :
                numbers_in[i][20] ? 6'd20 :
                numbers_in[i][21] ? 6'd21 :
                numbers_in[i][22] ? 6'd22 :
                numbers_in[i][23] ? 6'd23 :
                numbers_in[i][24] ? 6'd24 :
                numbers_in[i][25] ? 6'd25 :
                numbers_in[i][26] ? 6'd26 :
                numbers_in[i][27] ? 6'd27 :
                numbers_in[i][28] ? 6'd28 :
                numbers_in[i][29] ? 6'd29 :
                numbers_in[i][30] ? 6'd30 :
                numbers_in[i][31] ? 6'd31 :
                numbers_in[i][32] ? 6'd32 :
                numbers_in[i][33] ? 6'd33 :
                numbers_in[i][34] ? 6'd34 :
                numbers_in[i][35] ? 6'd35 :
                numbers_in[i][36] ? 6'd36 :
                numbers_in[i][37] ? 6'd37 :
                numbers_in[i][38] ? 6'd38 :
                numbers_in[i][39] ? 6'd39 :
                numbers_in[i][40] ? 6'd40 :
                numbers_in[i][41] ? 6'd41 :
                numbers_in[i][42] ? 6'd42 :
                numbers_in[i][43] ? 6'd43 :
                numbers_in[i][44] ? 6'd44 :
                numbers_in[i][45] ? 6'd45 :
                numbers_in[i][46] ? 6'd46 :
                numbers_in[i][47] ? 6'd47 :
                numbers_in[i][48] ? 6'd48 :
                numbers_in[i][49] ? 6'd49 :
                numbers_in[i][50] ? 6'd50 :
                numbers_in[i][51] ? 6'd51 :
                numbers_in[i][52] ? 6'd52 :
                numbers_in[i][53] ? 6'd53 :
                numbers_in[i][54] ? 6'd54 :
                numbers_in[i][55] ? 6'd55 :
                numbers_in[i][56] ? 6'd56 :
                numbers_in[i][57] ? 6'd57 :
                numbers_in[i][58] ? 6'd58 :
                numbers_in[i][59] ? 6'd59 :
                numbers_in[i][60] ? 6'd60 :
                numbers_in[i][61] ? 6'd61 :
                numbers_in[i][62] ? 6'd62 :
                numbers_in[i][63] ? 6'd63 : 6'd0
            );
            assign input_valid[i] = valid_in[i];
        end
    endgenerate

    // 2. Count frequencies of each ctz (0 to 63)
    reg [5:0] freq_cnt [0:63]; // Counts up to 16 fits in 5 bits, but using 6 bits for safety
    reg [5:0] max_freq;
    reg [5:0] best_ctz;
    integer j, k, idx;
    reg [5:0] current_ctz;

    always @(*) begin
        // Initialize counters
        for (j = 0; j < 64; j = j + 1) begin
            freq_cnt[j] = 6'b0;
        end

        // Tally frequencies
        for (k = 0; k < 16; k = k + 1) begin
            if (input_valid[k]) begin
                freq_cnt[ctz[k]] = freq_cnt[ctz[k]] + 1'b1;
            end
        end

        // Find max frequency and corresponding ctz
        // We must resolve ties deterministically. Priority to lowest ctz index.
        max_freq = 6'b0;
        best_ctz = 6'b0;
        
        for (idx = 0; idx < 64; idx = idx + 1) begin
            if (freq_cnt[idx] > max_freq) begin
                max_freq = freq_cnt[idx];
                best_ctz = idx[5:0];
            end
        end
    end

    // 3. Identify numbers to remove
    reg [15:0] r_mask;
    reg [63:0] r_vals [0:15];
    integer m;

    always @(*) begin
        r_mask = 16'b0;
        for (m = 0; m < 16; m = m + 1) begin
            if (input_valid[m]) begin
                if (ctz[m] != best_ctz) begin
                    r_mask[m] = 1'b1;
                    r_vals[m] = numbers_in[m];
                end else begin
                    r_vals[m] = 64'b0; // Clear unused output
                end
            end else begin
                r_vals[m] = 64'b0; // Clear unused output
            end
        end
    end

    assign remove_mask = r_mask;
    assign removed_values = r_vals;

endmodule