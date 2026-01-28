module typo_detector #(
    parameter N = 8,
    parameter MAX_LEN = 8,
    parameter CHAR_WIDTH = 8
)(
    input wire [N*MAX_LEN*CHAR_WIDTH-1:0] word_data,
    input wire [N*4-1:0] word_len,
    output wire [N-1:0] typo_mask
);

    wire [CHAR_WIDTH-1:0] words [0:N-1][0:MAX_LEN-1];
    wire [3:0] lens [0:N-1];

    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin: gen_unpack
            assign lens[i] = word_len[i*4 +: 4];
            for (j = 0; j < MAX_LEN; j = j + 1) begin: gen_unpack_char
                assign words[i][j] = word_data[(i*MAX_LEN + j)*CHAR_WIDTH +: CHAR_WIDTH];
            end
        end
    endgenerate

    reg [N-1:0] typo_mask_reg;
    assign typo_mask = typo_mask_reg;

    integer k, m, p, q;
    reg match_found;
    
    always @(*) begin
        typo_mask_reg = {N{1'b0}};
        
        for (k = 0; k < N; k = k + 1) begin
            if (lens[k] > 4'd0) begin
                for (p = 0; p < lens[k]; p = p + 1) begin
                    reg [CHAR_WIDTH-1:0] candidate [0:MAX_LEN-1];
                    
                    // Generate candidate by deleting character at position p
                    for (q = 0; q < (lens[k] - 1); q = q + 1) begin
                        if (q < p) candidate[q] = words[k][q];
                        else candidate[q] = words[k][q+1];
                    end
                    
                    // Check candidate against all other words
                    match_found = 1'b0;
                    for (m = 0; m < N; m = m + 1) begin
                        if (m != k && lens[m] == (lens[k] - 1)) begin
                            integer char_match;
                            char_match = 1;
                            for (q = 0; q < lens[m]; q = q + 1) begin
                                if (candidate[q] != words[m][q]) begin
                                    char_match = 0;
                                end
                            end
                            if (char_match) begin
                                match_found = 1'b1;
                            end
                        end
                    end
                    
                    if (match_found) begin
                        typo_mask_reg[k] = 1'b1;
                    end
                end
            end
        end
    end
endmodule