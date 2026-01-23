module typo_detector #(
    parameter N = 8,
    parameter MAX_LEN = 8,
    parameter CHAR_WIDTH = 8
)(
    input wire [N*MAX_LEN*CHAR_WIDTH-1:0] word_data,
    input wire [N*4-1:0] word_len,
    output wire [N-1:0] typo_mask
);

    // Unpack the inputs into arrays for easier access
    wire [CHAR_WIDTH-1:0] words [0:N-1][0:MAX_LEN-1];
    wire [3:0] lens [0:N-1];

    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin: gen_unpack
            assign lens[i] = word_len[i*4 +: 4];
            for (j = 0; j < MAX_LEN; j = j + 1) begin: gen_unpack2
                assign words[i][j] = word_data[(i*MAX_LEN + j)*CHAR_WIDTH +: CHAR_WIDTH];
            end
        end
    endgenerate

    // Combinational logic to compute typo mask
    assign typo_mask = compute_typo_mask();

    function automatic [N-1:0] compute_typo_mask;
        integer i, j, k, m;
        reg [CHAR_WIDTH-1:0] candidate [0:MAX_LEN-1];
        reg [3:0] cand_len;
        reg match;
        reg [N-1:0] mask_temp;
    begin
        mask_temp = {N{1'b0}};
        for (i = 0; i < N; i = i + 1) begin
            if (lens[i] > 0) begin
                for (j = 0; j < lens[i]; j = j + 1) begin
                    // Generate candidate by deleting j-th character
                    cand_len = lens[i] - 1;
                    for (m = 0; m < cand_len; m = m + 1) begin
                        if (m < j) candidate[m] = words[i][m];
                        else candidate[m] = words[i][m+1];
                    end
                    // Check if candidate matches any other word
                    match = 1'b0;
                    for (k = 0; k < N; k = k + 1) begin
                        if (k != i && lens[k] == cand_len) begin
                            match = 1'b1;
                            for (m = 0; m < cand_len; m = m + 1) begin
                                if (candidate[m] != words[k][m]) begin
                                    match = 1'b0;
                                end
                            end
                            if (match) begin
                                // Match found, set typo
                                mask_temp[i] = 1'b1;
                            end
                        end
                    end
                    if (mask_temp[i]) begin
                        break;
                    end
                end
            end
        end
        compute_typo_mask = mask_temp;
    end
    endfunction

endmodule