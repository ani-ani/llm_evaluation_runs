module word_length_filter (
  input [3:0] n,
  input [1023:0] word_string,
  output [7:0] word_mask
);
  
  genvar i, j;
  generate
    for (i=0; i<8; i=i+1) begin : word_loop
      wire [127:0] current_word = word_string[i*128 +: 128];
      reg [15:0] is_non_space;
      
      for (j=0; j<16; j=j+1) begin : char_loop
        always_comb begin
          wire [7:0] char = current_word[(15-j)*8 +: 8];
          is_non_space[j] = (char != 8'h20);
        end
      end
      
      assign word_mask[i] = ($countones(is_non_space) > n);
    end
  endgenerate

endmodule