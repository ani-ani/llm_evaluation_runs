module vowel_counter(
  input  [63:0] chars,
  input  [3:0]  len,
  output [3:0]  count
);

  // Extract bytes for convenience
  wire [7:0] c0 = chars[7:0];
  wire [7:0] c1 = chars[15:8];
  wire [7:0] c2 = chars[23:16];
  wire [7:0] c3 = chars[31:24];
  wire [7:0] c4 = chars[39:32];
  wire [7:0] c5 = chars[47:40];
  wire [7:0] c6 = chars[55:48];
  wire [7:0] c7 = chars[63:56];

  // Helper: standard vowel (a,e,i,o,u), case-insensitive
  function automatic is_std_vowel(input [7:0] ch);
    begin
      case (ch | 8'h20)
        8'h61, // a
        8'h65, // e
        8'h69, // i
        8'h6f, // o
        8'h75: // u
          is_std_vowel = 1'b1;
        default:
          is_std_vowel = 1'b0;
      endcase
    end
  endfunction

  // Helper: is 'y' or 'Y'
  function automatic is_y(input [7:0] ch);
    begin
      is_y = ((ch | 8'h20) == 8'h79); // 'y'
    end
  endfunction

  // Determine last valid index (0-7); only meaningful when len>0
  wire [2:0] last_idx = len[2:0] - 3'd1;

  // Validity per index based on len
  wire v0 = (len > 4'd0);
  wire v1 = (len > 4'd1);
  wire v2 = (len > 4'd2);
  wire v3 = (len > 4'd3);
  wire v4 = (len > 4'd4);
  wire v5 = (len > 4'd5);
  wire v6 = (len > 4'd6);
  wire v7 = (len > 4'd7);

  // Standard vowel detection per index (only if within len)
  wire s0 = v0 && is_std_vowel(c0);
  wire s1 = v1 && is_std_vowel(c1);
  wire s2 = v2 && is_std_vowel(c2);
  wire s3 = v3 && is_std_vowel(c3);
  wire s4 = v4 && is_std_vowel(c4);
  wire s5 = v5 && is_std_vowel(c5);
  wire s6 = v6 && is_std_vowel(c6);
  wire s7 = v7 && is_std_vowel(c7);

  // 'y' as vowel only when it is the last valid character (len>0)
  wire y0 = (len > 0) && (last_idx == 3'd0) && is_y(c0);
  wire y1 = (len > 0) && (last_idx == 3'd1) && is_y(c1);
  wire y2 = (len > 0) && (last_idx == 3'd2) && is_y(c2);
  wire y3 = (len > 0) && (last_idx == 3'd3) && is_y(c3);
  wire y4 = (len > 0) && (last_idx == 3'd4) && is_y(c4);
  wire y5 = (len > 0) && (last_idx == 3'd5) && is_y(c5);
  wire y6 = (len > 0) && (last_idx == 3'd6) && is_y(c6);
  wire y7 = (len > 0) && (last_idx == 3'd7) && is_y(c7);

  // Sum all qualifying vowels (standard + conditional 'y')
  wire [3:0] sum0 = s0 + s1 + s2 + s3;
  wire [3:0] sum1 = s4 + s5 + s6 + s7;
  wire [3:0] sum2 = y0 + y1 + y2 + y3;
  wire [3:0] sum3 = y4 + y5 + y6 + y7;

  assign count = sum0 + sum1 + sum2 + sum3;

endmodule