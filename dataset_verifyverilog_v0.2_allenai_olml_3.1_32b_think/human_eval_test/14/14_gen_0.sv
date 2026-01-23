module all_prefixes(input [7:0][7:0] input_string, input [2:0] input_length, output reg [7:0][7:0] prefixes, output reg [2:0] prefix_count);

always @(*) begin
    prefix_count = input_length == 0 ? 0 : input_length;
    genvar i, j;
    generate
        for (i=0; i<8; i++) begin: i_loop
            for (j=0; j<8; j++) begin: j_loop
                if (i < input_length && j <= i) begin
                    prefixes[i][j] = input_string[j];
                end else begin
                    prefixes[i][j] = 8'b0;
                end
            end
        end
    endgenerate
end

endmodule