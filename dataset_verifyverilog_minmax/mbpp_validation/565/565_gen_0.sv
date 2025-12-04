module string_splitter (
  input [7:0][7:0] packed_string,
  input [2:0] len,
  output wire [7:0] char0, char1, char2, char3, char4, char5, char6, char7,
  output reg [7:0] valid_mask
);

  // Split packed characters to individual outputs
  assign char0 = packed_string[0];
  assign char1 = packed_string[1];
  assign char2 = packed_string[2];
  assign char3 = packed_string[3];
  assign char4 = packed_string[4];
  assign char5 = packed_string[5];
  assign char6 = packed_string[6];
  assign char7 = packed_string[7];

  // Generate one-hot validity mask: bits [0]..[len-1] are 1, others 0
  generate
    genvar i;
    for (i = 0; i < 8; i++) begin : VALID_MASK_GEN
      always @* valid_mask[i] = (len > i) ? 1'b1 : 1'b0;
    end
  endgenerate

endmodule