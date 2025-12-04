module word_length_filter (
    input reg [3:0] n,
    input reg [1023:0] word_string,
    output reg [7:0] word_mask
);

    genvar i;
    generate
        for (i=0; i<8; i++) begin : word_loop
            always @(*) begin
                integer count = 0;
                for (integer j=0; j<16; j++) begin
                    if (word_string[i*128 + j*8 +: 8] != 8'h20) count = count + 1;
                end
                word_mask[i] = (count > n) ? 1'b1 : 1'b0;
            end
        end
    endgenerate

endmodule