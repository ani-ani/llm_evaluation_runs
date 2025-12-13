module remove_odd_chars(
  input  [7:0] str_in [0:7],
  output [7:0] str_out[0:3],
  output [2:0] out_len
);

  // Output mapping: even 1-based indices -> 0-based indices [1,3,5,7]
  assign str_out[0] = str_in[1];
  assign str_out[1] = str_in[3];
  assign str_out[2] = str_in[5];
  assign str_out[3] = str_in[7];

  // Compute effective input length from padding rule (unused bytes are 0)
  // Assumes non-zero bytes from index 0 up to length-1, then zeros.
  wire [3:0] in_len;
  assign in_len = (str_in[7] != 8'd0) ? 4'd8 :
                  (str_in[6] != 8'd0) ? 4'd7 :
                  (str_in[5] != 8'd0) ? 4'd6 :
                  (str_in[4] != 8'd0) ? 4'd5 :
                  (str_in[3] != 8'd0) ? 4'd4 :
                  (str_in[2] != 8'd0) ? 4'd3 :
                  (str_in[1] != 8'd0) ? 4'd2 :
                  (str_in[0] != 8'd0) ? 4'd1 :
                                        4'd0;

  // out_len = floor(in_len / 2)
  assign out_len = in_len[3:1];

endmodule