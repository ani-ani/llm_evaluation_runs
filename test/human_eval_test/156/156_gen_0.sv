module int_to_mini_roman(
  input      [9:0]   number,
  output reg [95:0]  roman_chars
);

  // Digit wires
  reg [3:0] thousands;
  reg [3:0] hundreds;
  reg [3:0] tens;
  reg [3:0] units;

  // Per-digit ROM outputs (each up to 4 chars -> 32 bits)
  reg [31:0] thousands_rom;
  reg [31:0] hundreds_rom;
  reg [31:0] tens_rom;
  reg [31:0] units_rom;

  // Length trackers for each digit group
  reg [2:0] thousands_len;
  reg [2:0] hundreds_len;
  reg [2:0] tens_len;
  reg [2:0] units_len;

  // Intermediate concat and length
  reg [63:0] temp_chars;
  reg [3:0]  temp_len;

  always @* begin
    // Clamp to valid range 1..1000 (behavior for 0 or >1000 not specified; clamp for safety)
    // If strict behavior is required, this can be changed to drive zeros or 'x.
    reg [9:0] n_clamped;
    if (number < 10'd1)
      n_clamped = 10'd1;
    else if (number > 10'd1000)
      n_clamped = 10'd1000;
    else
      n_clamped = number;

    // Split into decimal digits
    thousands = n_clamped / 10'd1000;
    hundreds  = (n_clamped % 10'd1000) / 10'd100;
    tens      = (n_clamped % 10'd100)  / 10'd10;
    units     =  n_clamped % 10'd10;

    // Default ROM outputs
    thousands_rom = 32'h00000000;
    hundreds_rom  = 32'h00000000;
    tens_rom      = 32'h00000000;
    units_rom     = 32'h00000000;

    thousands_len = 3'd0;
    hundreds_len  = 3'd0;
    tens_len      = 3'd0;
    units_len     = 3'd0;

    // Thousands (only 0 or 1 valid for 1..1000)
    case (thousands)
      4'd0: begin
        thousands_rom = 32'h00000000;
        thousands_len = 3'd0;
      end
      4'd1: begin
        // "m"
        thousands_rom = {8'h6D,24'h000000};
        thousands_len = 3'd1;
      end
      default: begin
        thousands_rom = 32'h00000000;
        thousands_len = 3'd0;
      end
    endcase

    // Hundreds digit (0-9), uses c(63), d(64), m(6D)
    case (hundreds)
      4'd0: begin
        hundreds_rom = 32'h00000000;
        hundreds_len = 3'd0;
      end
      4'd1: begin // c
        hundreds_rom = {8'h63,24'h000000};
        hundreds_len = 3'd1;
      end
      4'd2: begin // cc
        hundreds_rom = {8'h63,8'h63,16'h0000};
        hundreds_len = 3'd2;
      end
      4'd3: begin // ccc
        hundreds_rom = {8'h63,8'h63,8'h63,8'h00};
        hundreds_len = 3'd3;
      end
      4'd4: begin // cd
        hundreds_rom = {8'h63,8'h64,16'h0000};
        hundreds_len = 3'd2;
      end
      4'd5: begin // d
        hundreds_rom = {8'h64,24'h000000};
        hundreds_len = 3'd1;
      end
      4'd6: begin // dc
        hundreds_rom = {8'h64,8'h63,16'h0000};
        hundreds_len = 3'd2;
      end
      4'd7: begin // dcc
        hundreds_rom = {8'h64,8'h63,8'h63,8'h00};
        hundreds_len = 3'd3;
      end
      4'd8: begin // dccc
        hundreds_rom = {8'h64,8'h63,8'h63,8'h63};
        hundreds_len = 3'd4;
      end
      4'd9: begin // cm
        hundreds_rom = {8'h63,8'h6D,16'h0000};
        hundreds_len = 3'd2;
      end
      default: begin
        hundreds_rom = 32'h00000000;
        hundreds_len = 3'd0;
      end
    endcase

    // Tens digit (0-9), uses x(78), l(6C), c(63)
    case (tens)
      4'd0: begin
        tens_rom = 32'h00000000;
        tens_len = 3'd0;
      end
      4'd1: begin // x
        tens_rom = {8'h78,24'h000000};
        tens_len = 3'd1;
      end
      4'd2: begin // xx
        tens_rom = {8'h78,8'h78,16'h0000};
        tens_len = 3'd2;
      end
      4'd3: begin // xxx
        tens_rom = {8'h78,8'h78,8'h78,8'h00};
        tens_len = 3'd3;
      end
      4'd4: begin // xl
        tens_rom = {8'h78,8'h6C,16'h0000};
        tens_len = 3'd2;
      end
      4'd5: begin // l
        tens_rom = {8'h6C,24'h000000};
        tens_len = 3'd1;
      end
      4'd6: begin // lx
        tens_rom = {8'h6C,8'h78,16'h0000};
        tens_len = 3'd2;
      end
      4'd7: begin // lxx
        tens_rom = {8'h6C,8'h78,8'h78,8'h00};
        tens_len = 3'd3;
      end
      4'd8: begin // lxxx
        tens_rom = {8'h6C,8'h78,8'h78,8'h78};
        tens_len = 3'd4;
      end
      4'd9: begin // xc
        tens_rom = {8'h78,8'h63,16'h0000};
        tens_len = 3'd2;
      end
      default: begin
        tens_rom = 32'h00000000;
        tens_len = 3'd0;
      end
    endcase

    // Units digit (0-9), uses i(69), v(76), x(78)
    case (units)
      4'd0: begin
        units_rom = 32'h00000000;
        units_len = 3'd0;
      end
      4'd1: begin // i
        units_rom = {8'h69,24'h000000};
        units_len = 3'd1;
      end
      4'd2: begin // ii
        units_rom = {8'h69,8'h69,16'h0000};
        units_len = 3'd2;
      end
      4'd3: begin // iii
        units_rom = {8'h69,8'h69,8'h69,8'h00};
        units_len = 3'd3;
      end
      4'd4: begin // iv
        units_rom = {8'h69,8'h76,16'h0000};
        units_len = 3'd2;
      end
      4'd5: begin // v
        units_rom = {8'h76,24'h000000};
        units_len = 3'd1;
      end
      4'd6: begin // vi
        units_rom = {8'h76,8'h69,16'h0000};
        units_len = 3'd2;
      end
      4'd7: begin // vii
        units_rom = {8'h76,8'h69,8'h69,8'h00};
        units_len = 3'd3;
      end
      4'd8: begin // viii
        units_rom = {8'h76,8'h69,8'h69,8'h69};
        units_len = 3'd4;
      end
      4'd9: begin // ix
        units_rom = {8'h69,8'h78,16'h0000};
        units_len = 3'd2;
      end
      default: begin
        units_rom = 32'h00000000;
        units_len = 3'd0;
      end
    endcase

    // Concatenate in order: thousands, hundreds, tens, units
    // Max length = 12 chars; temp_chars holds up to 8 chars, so we'll build stepwise.

    // First combine thousands + hundreds into upper 32 bits of temp_chars
    // Then append tens and units to form up to 8 chars total in temp_chars.

    // Start with thousands
    temp_chars = 64'h0;
    temp_len   = 4'd0;

    // Append thousands
    if (thousands_len != 3'd0) begin
      temp_chars[63 -: 8] = thousands_rom[31 -: 8];
      temp_len = temp_len + thousands_len; // thousands_len is 0 or 1
    end

    // Append hundreds
    if (hundreds_len != 3'd0) begin
      case (hundreds_len)
        3'd1: begin
          temp_chars[63 - 8*temp_len -: 8] = hundreds_rom[31 -: 8];
        end
        3'd2: begin
          temp_chars[63 - 8*temp_len -: 16] = hundreds_rom[31 -: 16];
        end
        3'd3: begin
          temp_chars[63 - 8*temp_len -: 24] = hundreds_rom[31 -: 24];
        end
        3'd4: begin
          temp_chars[63 - 8*temp_len -: 32] = hundreds_rom[31 -: 32];
        end
        default: ;
      endcase
      temp_len = temp_len + hundreds_len;
    end

    // Append tens
    if (tens_len != 3'd0) begin
      case (tens_len)
        3'd1: begin
          temp_chars[63 - 8*temp_len -: 8] = tens_rom[31 -: 8];
        end
        3'd2: begin
          temp_chars[63 - 8*temp_len -: 16] = tens_rom[31 -: 16];
        end
        3'd3: begin
          temp_chars[63 - 8*temp_len -: 24] = tens_rom[31 -: 24];
        end
        3'd4: begin
          temp_chars[63 - 8*temp_len -: 32] = tens_rom[31 -: 32];
        end
        default: ;
      endcase
      temp_len = temp_len + tens_len;
    end

    // Append units
    if (units_len != 3'd0) begin
      case (units_len)
        3'd1: begin
          temp_chars[63 - 8*temp_len -: 8] = units_rom[31 -: 8];
        end
        3'd2: begin
          temp_chars[63 - 8*temp_len -: 16] = units_rom[31 -: 16];
        end
        3'd3: begin
          temp_chars[63 - 8*temp_len -: 24] = units_rom[31 -: 24];
        end
        3'd4: begin
          temp_chars[63 - 8*temp_len -: 32] = units_rom[31 -: 32];
        end
        default: ;
      endcase
      temp_len = temp_len + units_len;
    end

    // Map 0..temp_len-1 chars from temp_chars (left-aligned there) into 12-byte roman_chars (left-aligned, zero-padded)
    // temp_chars uses [63:0] with first char at [63:56], etc.

    roman_chars = 96'h0;

    // Copy characters
    begin : pack_output
      integer i;
      for (i = 0; i < 12; i = i + 1) begin
        if (i < temp_len)
          roman_chars[95 - 8*i -: 8] = temp_chars[63 - 8*i -: 8];
        else
          roman_chars[95 - 8*i -: 8] = 8'h00;
      end
    end

  end

endmodule