module cyclic_codec (input [71:0] str_in, input mode, output reg [71:0] str_out);
  wire [7:0] byte0 = str_in[7:0];
  wire [7:0] byte1 = str_in[15:8];
  wire [7:0] byte2 = str_in[23:16];
  wire [7:0] byte3 = str_in[31:24];
  wire [7:0] byte4 = str_in[39:32];
  wire [7:0] byte5 = str_in[47:40];
  wire [7:0] byte6 = str_in[55:48];
  wire [7:0] byte7 = str_in[63:56];
  wire [7:0] byte8 = str_in[71:64];

  wire group0_complete = (byte0 != 8'h00) && (byte1 != 8'h00) && (byte2 != 8'h00);
  wire [23:0] group0_original = {byte2, byte1, byte0};
  wire [23:0] group0_encoded = {byte1, byte2, byte0};
  wire [23:0] group0_decoded = {byte2, byte0, byte1};
  wire [23:0] group0_out = group0_complete ? (mode ? group0_decoded : group0_encoded) : group0_original;

  wire group1_complete = (byte3 != 8'h00) && (byte4 != 8'h00) && (byte5 != 8'h00);
  wire [23:0] group1_original = {byte5, byte4, byte3};
  wire [23:0] group1_encoded = {byte4, byte5, byte3};
  wire [23:0] group1_decoded = {byte5, byte3, byte4};
  wire [23:0] group1_out = group1_complete ? (mode ? group1_decoded : group1_encoded) : group1_original;

  wire group2_complete = (byte6 != 8'h00) && (byte7 != 8'h00) && (byte8 != 8'h00);
  wire [23:0] group2_original = {byte8, byte7, byte6};
  wire [23:0] group2_encoded = {byte7, byte8, byte6};
  wire [23:0] group2_decoded = {byte8, byte6, byte7};
  wire [23:0] group2_out = group2_complete ? (mode ? group2_decoded : group2_encoded) : group2_original;

  always @* begin
    str_out = {group2_out, group1_out, group0_out};
  end
endmodule