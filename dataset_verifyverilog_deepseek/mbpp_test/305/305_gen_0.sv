module find_p_words (
  input [127:0] str_input,
  output reg [63:0] word1,
  output reg [63:0] word2,
  output reg valid
);

  wire [7:0] bytes [0:15];
  assign bytes[0] = str_input[127:120];
  assign bytes[1] = str_input[119:112];
  assign bytes[2] = str_input[111:104];
  assign bytes[3] = str_input[103:96];
  assign bytes[4] = str_input[95:88];
  assign bytes[5] = str_input[87:80];
  assign bytes[6] = str_input[79:72];
  assign bytes[7] = str_input[71:64];
  assign bytes[8] = str_input[63:56];
  assign bytes[9] = str_input[55:48];
  assign bytes[10] = str_input[47:40];
  assign bytes[11] = str_input[39:32];
  assign bytes[12] = str_input[31:24];
  assign bytes[13] = str_input[23:16];
  assign bytes[14] = str_input[15:8];
  assign bytes[15] = str_input[7:0];

  wire [15:0] space_mask;
  assign space_mask[0] = (bytes[0] == 8'h20);
  assign space_mask[1] = (bytes[1] == 8'h20);
  assign space_mask[2] = (bytes[2] == 8'h20);
  assign space_mask[3] = (bytes[3] == 8'h20);
  assign space_mask[4] = (bytes[4] == 8'h20);
  assign space_mask[5] = (bytes[5] == 8'h20);
  assign space_mask[6] = (bytes[6] == 8'h20);
  assign space_mask[7] = (bytes[7] == 8'h20);
  assign space_mask[8] = (bytes[8] == 8'h20);
  assign space_mask[9] = (bytes[9] == 8'h20);
  assign space_mask[10] = (bytes[10] == 8'h20);
  assign space_mask[11] = (bytes[11] == 8'h20);
  assign space_mask[12] = (bytes[12] == 8'h20);
  assign space_mask[13] = (bytes[13] == 8'h20);
  assign space_mask[14] = (bytes[14] == 8'h20);
  assign space_mask[15] = (bytes[15] == 8'h20);

  reg [3:0] space_pos;
  reg space_found;

  always_comb begin
    space_found = 1'b0;
    space_pos = 4'h0;
    for (int i = 0; i < 16; i++) begin
      if (!space_found && space_mask[i]) begin
        space_found = 1'b1;
        space_pos = i[3:0];
      end
    end
  end

  always_comb begin
    word1 = 64'h0;
    word2 = 64'h0;
    valid = 1'b0;

    if (space_found && space_pos >= 4'd1 && space_pos <= 4'd14) begin
      for (int j = 0; j < 8; j++) begin
        if (j < space_pos) word1[63 - j*8 -:8] = bytes[j];
        else word1[63 - j*8 -:8] = 8'h00;
      end

      for (int j = 0; j < 8; j++) begin
        int idx = space_pos + 1 + j;
        if (idx < 16) word2[63 - j*8 -:8] = bytes[idx];
        else word2[63 - j*8 -:8] = 8'h00;
      end

      if (bytes[0] == 8'h50 && bytes[space_pos+1] == 8'h50) valid = 1'b1;
    end
  end
endmodule