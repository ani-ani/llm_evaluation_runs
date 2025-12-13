module string_splitter(
  input      [7:0][7:0] packed_string,
  input      [2:0]      len,
  output reg [7:0]      char0,
  output reg [7:0]      char1,
  output reg [7:0]      char2,
  output reg [7:0]      char3,
  output reg [7:0]      char4,
  output reg [7:0]      char5,
  output reg [7:0]      char6,
  output reg [7:0]      char7,
  output reg [7:0]      valid_mask
);

  always @(*) begin
    // Direct character extraction
    char0 = packed_string[0];
    char1 = packed_string[1];
    char2 = packed_string[2];
    char3 = packed_string[3];
    char4 = packed_string[4];
    char5 = packed_string[5];
    char6 = packed_string[6];
    char7 = packed_string[7];

    // Valid mask generation based on len (0-7)
    case (len)
      3'd0: valid_mask = 8'b0000_0000;
      3'd1: valid_mask = 8'b0000_0001;
      3'd2: valid_mask = 8'b0000_0011;
      3'd3: valid_mask = 8'b0000_0111;
      3'd4: valid_mask = 8'b0000_1111;
      3'd5: valid_mask = 8'b0001_1111;
      3'd6: valid_mask = 8'b0011_1111;
      3'd7: valid_mask = 8'b0111_1111;
      default: valid_mask = 8'b1111_1111; // For completeness if len > 7
    endcase
  end

endmodule