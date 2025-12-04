module int_to_mini_roman (
  input wire [9:0] number,
  output reg [95:0] roman_chars
);

  reg [3:0] thousands, hundreds, tens, units;
  reg [7:0] temp_thousands;
  reg [31:0] temp_hundreds, temp_tens, temp_units;
  reg [7:0] byte_array [0:12];
  integer i, pos;

  always_comb begin
    thousands = number / 1000;
    hundreds = (number % 1000) / 100;
    tens = (number % 100) / 10;
    units = number % 10;

    // Thousands
    temp_thousands = (thousands != 0) ? 8'h6D : 8'h00;

    // Hundreds
    case (hundreds)
      4'd0: temp_hundreds = 32'h00000000;
      4'd1: temp_hundreds = {8'h63, 24'h0};
      4'd2: temp_hundreds = {16'h6363, 16'h0};
      4'd3: temp_hundreds = {24'h636363, 8'h0};
      4'd4: temp_hundreds = {16'h6364, 16'h0};
      4'd5: temp_hundreds = {8'h64, 24'h0};
      4'd6: temp_hundreds = {16'h6463, 16'h0};
      4'd7: temp_hundreds = {24'h646363, 8'h0};
      4'd8: temp_hundreds = {8'h64, 8'h63, 8'h63, 8'h63};
      4'd9: temp_hundreds = {16'h636D, 16'h0};
      default: temp_hundreds = 32'h0;
    endcase

    // Tens
    case (tens)
      4'd0: temp_tens = 32'h00000000;
      4'd1: temp_tens = {8'h78, 24'h0};
      4'd2: temp_tens = {16'h7878, 16'h0};
      4'd3: temp_tens = {24'h787878, 8'h0};
      4'd4: temp_tens = {16'h786C, 16'h0};
      4'd5: temp_tens = {8'h6C, 24'h0};
      4'd6: temp_tens = {16'h6C78, 16'h0};
      4'd7: temp_tens = {24'h6C7878, 8'h0};
      4'd8: temp_tens = {8'h6C, 8'h78, 8'h78, 8'h78};
      4'd9: temp_tens = {16'h7863, 16'h0};
      default: temp_tens = 32'h0;
    endcase

    // Units
    case (units)
      4'd0: temp_units = 32'h00000000;
      4'd1: temp_units = {8'h69, 24'h0};
      4'd2: temp_units = {16'h6969, 16'h0};
      4'd3: temp_units = {24'h696969, 8'h0};
      4'd4: temp_units = {16'h6976, 16'h0};
      4'd5: temp_units = {8'h76, 24'h0};
      4'd6: temp_units = {16'h7669, 16'h0};
      4'd7: temp_units = {24'h766969, 8'h0};
      4'd8: temp_units = {8'h76, 8'h69, 8'h69, 8'h69};
      4'd9: temp_units = {16'h6978, 16'h0};
      default: temp_units = 32'h0;
    endcase

    // Fill the byte_array
    byte_array[0] = temp_thousands;
    byte_array[1] = temp_hundreds[31:24];
    byte_array[2] = temp_hundreds[23:16];
    byte_array[3] = temp_hundreds[15:8];
    byte_array[4] = temp_hundreds[7:0];
    byte_array[5] = temp_tens[31:24];
    byte_array[6] = temp_tens[23:16];
    byte_array[7] = temp_tens[15:8];
    byte_array[8] = temp_tens[7:0];
    byte_array[9] = temp_units[31:24];
    byte_array[10] = temp_units[23:16];
    byte_array[11] = temp_units[15:8];
    byte_array[12] = temp_units[7:0];

    roman_chars = 96'h0;
    pos = 0;
    for (i=0; i<13; i=i+1) begin
      if (pos < 12 && byte_array[i] != 8'h00) begin
        roman_chars = (roman_chars << 8) | byte_array[i];
        pos = pos + 1;
      end
    end
  end
endmodule