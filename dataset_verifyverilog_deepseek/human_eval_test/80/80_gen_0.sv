module happy_string(input [3:0] str_len, input [63:0] str_data, output reg happy);
  wire [5:0] happy_triplet;
  genvar i;
  generate
    for (i = 0; i < 6; i = i + 1) begin : triplet_check
      wire [7:0] char0 = str_data[i*8 +: 8];
      wire [7:0] char1 = str_data[(i+1)*8 +: 8];
      wire [7:0] char2 = str_data[(i+2)*8 +: 8];
      wire triplet_valid = (i < (str_len - 4'd2)) && (str_len >= 4'd3);
      wire distinct = (char0 != char1) && (char0 != char2) && (char1 != char2);
      assign happy_triplet[i] = triplet_valid ? distinct : 1'b1;
    end
  endgenerate

  always_comb begin
    if (str_len < 4'd3) happy = 1'b0;
    else happy = &happy_triplet;
  end
endmodule