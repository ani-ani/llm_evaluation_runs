module string_filter (
  input [127:0] str1, // 16 bytes, LSB = first character
  input [127:0] str2, // 16 bytes, LSB = first character
  output reg [127:0] filtered_str // 16 bytes packed from LSB, unused bytes zeroed
);

  // Presence bitmap (256 bits): bit c is 1 if ASCII char c appears in str2
  // Compute: 256'b1 & (==? str2 bytes == 8'(c))
  logic [255:0] presence;
  genvar gci, gcj;
  generate
    for (gci = 0; gci < 256; gci++) begin : presence_loop
      logic [255:0] eq_mask;
      // eq_mask[gcj*8 +: 8] is 0xFF iff str2[byte gcj] == 8'(gci), else 0
      for (gcj = 0; gcj < 16; gcj++) begin : eq_inner
        assign eq_mask[gcj*8 +: 8] = (str2[gcj*8 +: 8] == gci[7:0]) ? 8'hFF : 8'h0;
      end
      // Any byte equal to gci sets the bit
      assign presence[gci] = (| eq_mask);
    end
  endgenerate

  // --- Compute per-character keep flags from str1 (parallel) ---
  // keep[i] = 1 if str1 byte i should be kept (not present in str2)
  logic [15:0] keep; // bit i -> keep character i of str1
  logic [7:0] ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7, ch8, ch9, ch10, ch11, ch12, ch13, ch14, ch15;
  assign ch0  = str1[7:0];    assign ch1  = str1[15:8];   assign ch2  = str1[23:16];  assign ch3  = str1[31:24];
  assign ch4  = str1[39:32];  assign ch5  = str1[47:40];  assign ch6  = str1[55:48];  assign ch7  = str1[63:56];
  assign ch8  = str1[71:64];  assign ch9  = str1[79:72];  assign ch10 = str1[87:80];  assign ch11 = str1[95:88];
  assign ch12 = str1[103:96]; assign ch13 = str1[111:104];assign ch14 = str1[119:112];assign ch15 = str1[127:120];

  assign keep[0]  = ~presence[ ch0 ];
  assign keep[1]  = ~presence[ ch1 ];
  assign keep[2]  = ~presence[ ch2 ];
  assign keep[3]  = ~presence[ ch3 ];
  assign keep[4]  = ~presence[ ch4 ];
  assign keep[5]  = ~presence[ ch5 ];
  assign keep[6]  = ~presence[ ch6 ];
  assign keep[7]  = ~presence[ ch7 ];
  assign keep[8]  = ~presence[ ch8 ];
  assign keep[9]  = ~presence[ ch9 ];
  assign keep[10] = ~presence[ ch10];
  assign keep[11] = ~presence[ ch11];
  assign keep[12] = ~presence[ ch12];
  assign keep[13] = ~presence[ ch13];
  assign keep[14] = ~presence[ ch14];
  assign keep[15] = ~presence[ ch15];

  // --- Prefix count of kept characters: cnt[i] = #kept among str1[0..i] ---
  logic [3:0] cnt0, cnt1, cnt2, cnt3, cnt4, cnt5, cnt6, cnt7;
  logic [3:0] cnt8, cnt9, cnt10, cnt11, cnt12, cnt13, cnt14, cnt15;
  assign cnt0  = keep[0];
  assign cnt1  = cnt0  + keep[1];
  assign cnt2  = cnt1  + keep[2];
  assign cnt3  = cnt2  + keep[3];
  assign cnt4  = cnt3  + keep[4];
  assign cnt5  = cnt4  + keep[5];
  assign cnt6  = cnt5  + keep[6];
  assign cnt7  = cnt6  + keep[7];
  assign cnt8  = cnt7  + keep[8];
  assign cnt9  = cnt8  + keep[9];
  assign cnt10 = cnt9  + keep[10];
  assign cnt11 = cnt10 + keep[11];
  assign cnt12 = cnt11 + keep[12];
  assign cnt13 = cnt12 + keep[13];
  assign cnt14 = cnt13 + keep[14];
  assign cnt15 = cnt14 + keep[15];

  // Offset (in bytes) where this character will be placed in the output if kept
  // For character i: offset = cnt[i-1] (0 if i is first)
  logic [3:0] offset0, offset1, offset2, offset3, offset4, offset5, offset6, offset7;
  logic [3:0] offset8, offset9, offset10, offset11, offset12, offset13, offset14, offset15;
  assign offset0  = 4'd0;           // #kept before position 0
  assign offset1  = cnt0;
  assign offset2  = cnt1;
  assign offset3  = cnt2;
  assign offset4  = cnt3;
  assign offset5  = cnt4;
  assign offset6  = cnt5;
  assign offset7  = cnt6;
  assign offset8  = cnt7;
  assign offset9  = cnt8;
  assign offset10 = cnt9;
  assign offset11 = cnt10;
  assign offset12 = cnt11;
  assign offset13 = cnt12;
  assign offset14 = cnt13;
  assign offset15 = cnt14;

  // --- 16-entry 16-way mux to pick the 8-bit slice for each output position ---
  // Each position p (0..15) chooses a character from str1 whose offset == p (if any),
  // else yields 8'b0. Offsets < 16 always fit because at most 16 bytes are kept.
  // We use a priority/selection scheme: scan from i=15 down to 0 and pick the first i with offset == p and keep[i].
  // This is implemented as a 2D mux with balanced tree of priorities.

  // Input data: 16 bytes, each placed at its 8*i offset position (if kept), else 0
  // We simply select the correct source via a 16-way selector per output position.

  // Pre-create per-byte selects for readability; actual selection is inline below.

  function [7:0] pick_byte(
    input [3:0] p,
    input [3:0] off0, off1, off2, off3, off4, off5, off6, off7,
    input [3:0] off8, off9, off10, off11, off12, off13, off14, off15,
    input keep0, keep1, keep2, keep3, keep4, keep5, keep6, keep7,
    input keep8, keep9, keep10, keep11, keep12, keep13, keep14, keep15,
    input [7:0] b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15
  );
    begin
      // Priority: higher i wins when multiple map to same p (stable: rightmost wins)
      // Build four stages to reduce 16 inputs to 1.
      logic [7:0] s0, s1, s2, s3;
      // Stage 0: pairs (15,14), (13,12), (11,10), (9,8), (7,6), (5,4), (3,2), (1,0)
      s0 = (off15 == p && keep15) ? b15 :
           (off14 == p && keep14) ? b14 : 8'h0;
      s1 = (off13 == p && keep13) ? b13 :
           (off12 == p && keep12) ? b12 : 8'h0;
      s2 = (off11 == p && keep11) ? b11 :
           (off10 == p && keep10) ? b10 : 8'h0;
      s3 = (off9  == p && keep9 ) ? b9  :
           (off8  == p && keep8 ) ? b8  : 8'h0;
      // Stage 1: pairs of stage outputs
      s0 = (|s0) ? s0 : s1;
      s1 = (|s2) ? s2 : s3;
      // Stage 2
      s0 = (|s0) ? s0 : s1;
      // Stage 3: check lower positions (7..0) to ensure stable priority if upper map
      if (off7 == p && keep7) s0 = b7;
      if (off6 == p && keep6) s0 = b6;
      if (off5 == p && keep5) s0 = b5;
      if (off4 == p && keep4) s0 = b4;
      if (off3 == p && keep3) s0 = b3;
      if (off2 == p && keep2) s0 = b2;
      if (off1 == p && keep1) s0 = b1;
      if (off0 == p && keep0) s0 = b0;
      pick_byte = s0;
    end
  endfunction

  logic [7:0] out0, out1, out2, out3, out4, out5, out6, out7;
  logic [7:0] out8, out9, out10, out11, out12, out13, out14, out15;

  assign out0  = pick_byte(4'd0,  offset0, offset1, offset2, offset3, offset4, offset5, offset6, offset7,
                           offset8, offset9, offset10, offset11, offset12, offset13, offset14, offset15,
                           keep0, keep1, keep2, keep3, keep4, keep5, keep6, keep7,
                           keep8, keep9, keep10, keep11, keep12, keep13, keep14, keep15,
                           ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7, ch8, ch9, ch10, ch11, ch12, ch13, ch14, ch15);
  assign out1  = pick_byte(4'd1,  offset0, offset1, offset2, offset3, offset4, offset5, offset6, offset7,
                           offset8, offset9, offset10, offset11, offset12, offset13, offset14, offset15,
                           keep0, keep1, keep2, keep3, keep4, keep5, keep6, keep7,
                           keep8, keep9, keep10, keep11, keep12, keep13, keep14, keep15,
                           ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7, ch8, ch9, ch10, ch11, ch12, ch13, ch14, ch15);
  assign out2  = pick_byte(4'd2,  offset0, offset1, offset2, offset3, offset4, offset5, offset6, offset7,
                           offset8, offset9, offset10, offset11, offset12, offset13, offset14, offset15,
                           keep0, keep1, keep2, keep3, keep4, keep5, keep6, keep7,
                           keep8, keep9, keep10, keep11, keep12, keep13, keep14, keep15,
                           ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7, ch8, ch9, ch10, ch11, ch12, ch13, ch14, ch15);
  assign out3  = pick_byte(4'd3,  offset0, offset1, offset2, offset3, offset4, offset5, offset6, offset7,
                           offset8, offset9, offset10, offset11, offset12, offset13, offset14, offset15,
                           keep0, keep1, keep2, keep3, keep4, keep5, keep6, keep7,
                           keep8, keep9, keep10, keep11, keep12, keep13, keep14, keep15,
                           ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7, ch8, ch9, ch10, ch11, ch12, ch13, ch14, ch15);
  assign out4  = pick_byte(4'd4,  offset0, offset1, offset2, offset3, offset4, offset5, offset6, offset7,
                           offset8, offset9, offset10, offset11, offset12, offset13, offset14, offset15,
                           keep0, keep1, keep2, keep3, keep4, keep5, keep6, keep7,
                           keep8, keep9, keep10, keep11, keep12, keep13, keep14, keep15,
                           ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7, ch8, ch9, ch10, ch11, ch12, ch13, ch14, ch15);
  assign out5  = pick_byte(4'd5,  offset0, offset1, offset2, offset3, offset4, offset5, offset6, offset7,
                           offset8, offset9, offset10, offset11, offset12, offset13, offset14, offset15,
                           keep0, keep1, keep2, keep3, keep4, keep5, keep6, keep7,
                           keep8, keep9, keep10, keep11, keep12, keep13, keep14, keep15,
                           ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7, ch8, ch9, ch10, ch11, ch12, ch13, ch14, ch15);
  assign out6  = pick_byte(4'd6,  offset0, offset1, offset2, offset3, offset4, offset5, offset6, offset7,
                           offset8, offset9, offset10, offset11, offset12, offset13, offset14, offset15,
                           keep0, keep1, keep2, keep3, keep4, keep5, keep6, keep7,
                           keep8, keep9, keep10, keep11, keep12, keep13, keep14, keep15,
                           ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7, ch8, ch9, ch10, ch11, ch12, ch13, ch14, ch15);
  assign out7  = pick_byte(4'd7,  offset0, offset1, offset2, offset3, offset4, offset5, offset6, offset7,
                           offset8, offset9, offset10, offset11, offset12, offset13, offset14, offset15,
                           keep0, keep1, keep2, keep3, keep4, keep5, keep6, keep7,
                           keep8, keep9, keep10, keep11, keep12, keep13, keep14, keep15,
                           ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7, ch8, ch9, ch10, ch11, ch12, ch13, ch14, ch15);
  assign out8  = pick_byte(4'd8,  offset0, offset1, offset2, offset3, offset4, offset5, offset6, offset7,
                           offset8, offset9, offset10, offset11, offset12, offset13, offset14, offset15,
                           keep0, keep1, keep2, keep3, keep4, keep5, keep6, keep7,
                           keep8, keep9, keep10, keep11, keep12, keep13, keep14, keep15,
                           ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7, ch8, ch9, ch10, ch11, ch12, ch13, ch14, ch15);
  assign out9  = pick_byte(4'd9,  offset0, offset1, offset2, offset3, offset4, offset5, offset6, offset7,
                           offset8, offset9, offset10, offset11, offset12, offset13, offset14, offset15,
                           keep0, keep1, keep2, keep3, keep4, keep5, keep6, keep7,
                           keep8, keep9, keep10, keep11, keep12, keep13, keep14, keep15,
                           ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7, ch8, ch9, ch10, ch11, ch12, ch13, ch14, ch15);
  assign out10 = pick_byte(4'd10, offset0, offset1, offset2, offset3, offset4, offset5, offset6, offset7,
                           offset8, offset9, offset10, offset11, offset12, offset13, offset14, offset15,
                           keep0, keep1, keep2, keep3, keep4, keep5, keep6, keep7,
                           keep8, keep9, keep10, keep11, keep12, keep13, keep14, keep15,
                           ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7, ch8, ch9, ch10, ch11, ch12, ch13, ch14, ch15);
  assign out11 = pick_byte(4'd11, offset0, offset1, offset2, offset3, offset4, offset5, offset6, offset7,
                           offset8, offset9, offset10, offset11, offset12, offset13, offset14, offset15,
                           keep0, keep1, keep2, keep3, keep4, keep5, keep6, keep7,
                           keep8, keep9, keep10, keep11, keep12, keep13, keep14, keep15,
                           ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7, ch8, ch9, ch10, ch11, ch12, ch13, ch14, ch15);
  assign out12 = pick_byte(4'd12, offset0, offset1, offset2, offset3, offset4, offset5, offset6, offset7,
                           offset8, offset9, offset10, offset11, offset12, offset13, offset14, offset15,
                           keep0, keep1, keep2, keep3, keep4, keep5, keep6, keep7,
                           keep8, keep9, keep10, keep11, keep12, keep13, keep14, keep15,
                           ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7, ch8, ch9, ch10, ch11, ch12, ch13, ch14, ch15);
  assign out13 = pick_byte(4'd13, offset0, offset1, offset2, offset3, offset4, offset5, offset6, offset7,
                           offset8, offset9, offset10, offset11, offset12, offset13, offset14, offset15,
                           keep0, keep1, keep2, keep3, keep4, keep5, keep6, keep7,
                           keep8, keep9, keep10, keep11, keep12, keep13, keep14, keep15,
                           ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7, ch8, ch9, ch10, ch11, ch12, ch13, ch14, ch15);
  assign out14 = pick_byte(4'd14, offset0, offset1, offset2, offset3, offset4, offset5, offset6, offset7,
                           offset8, offset9, offset10, offset11, offset12, offset13, offset14, offset15,
                           keep0, keep1, keep2, keep3, keep4, keep5, keep6, keep7,
                           keep8, keep9, keep10, keep11, keep12, keep13, keep14, keep15,
                           ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7, ch8, ch9, ch10, ch11, ch12, ch13, ch14, ch15);
  assign out15 = pick_byte(4'd15, offset0, offset1, offset2, offset3, offset4, offset5, offset6, offset7,
                           offset8, offset9, offset10, offset11, offset12, offset13, offset14, offset15,
                           keep0, keep1, keep2, keep3, keep4, keep5, keep6, keep7,
                           keep8, keep9, keep10, keep11, keep12, keep13, keep14, keep15,
                           ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7, ch8, ch9, ch10, ch11, ch12, ch13, ch14, ch15);

  // Pack outputs to LSB-order 128-bit vector: out0 at [7:0], out1 at [15:8], ...
  always_comb begin
    filtered_str = {out15, out14, out13, out12, out11, out10, out9, out8,
                    out7,  out6,  out5,  out4,  out3,  out2,  out1, out0};
  end

endmodule
