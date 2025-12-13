module camel_order_verifier(
  input  [2:0]  n,          // Number of camels (2-8)
  input  [23:0] jaap_bet,   // 8x3-bit camels [MSB: a1 a2 ... a8 LSB]
  input  [23:0] jan_bet,    // Same format
  input  [23:0] thijs_bet,  // Same format
  output [4:0]  count       // Result count (0-28)
);

  // Position arrays per bettor, 8 camels max, positions fit in 3 bits (0-7)
  wire [2:0] pos_jp [1:8];
  wire [2:0] pos_jn [1:8];
  wire [2:0] pos_th [1:8];

  // Extract sequences (a1..a8) for each bet
  wire [2:0] jp_cam [0:7];
  wire [2:0] jn_cam [0:7];
  wire [2:0] th_cam[0:7];

  genvar gi;

  // Decode 3-bit camel IDs for each rank position from MSB to LSB
  generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : DECODE_CAMS
      assign jp_cam[gi]  = jaap_bet [23 - gi*3 -: 3];
      assign jn_cam[gi]  = jan_bet  [23 - gi*3 -: 3];
      assign th_cam[gi]  = thijs_bet[23 - gi*3 -: 3];
    end
  endgenerate

  // Build position tables: pos_x[id] = index (0..7) where that camel id appears
  // We assume valid permutations containing each camel at most once.
  genvar id;
  generate
    for (id = 1; id <= 8; id = id + 1) begin : BUILD_POS
      // Find position in Jaap bet
      assign pos_jp[id] = (jp_cam[0] == id[2:0]) ? 3'd0 :
                          (jp_cam[1] == id[2:0]) ? 3'd1 :
                          (jp_cam[2] == id[2:0]) ? 3'd2 :
                          (jp_cam[3] == id[2:0]) ? 3'd3 :
                          (jp_cam[4] == id[2:0]) ? 3'd4 :
                          (jp_cam[5] == id[2:0]) ? 3'd5 :
                          (jp_cam[6] == id[2:0]) ? 3'd6 :
                          (jp_cam[7] == id[2:0]) ? 3'd7 : 3'd7;

      // Find position in Jan bet
      assign pos_jn[id] = (jn_cam[0] == id[2:0]) ? 3'd0 :
                          (jn_cam[1] == id[2:0]) ? 3'd1 :
                          (jn_cam[2] == id[2:0]) ? 3'd2 :
                          (jn_cam[3] == id[2:0]) ? 3'd3 :
                          (jn_cam[4] == id[2:0]) ? 3'd4 :
                          (jn_cam[5] == id[2:0]) ? 3'd5 :
                          (jn_cam[6] == id[2:0]) ? 3'd6 :
                          (jn_cam[7] == id[2:0]) ? 3'd7 : 3'd7;

      // Find position in Thijs bet
      assign pos_th[id] = (th_cam[0] == id[2:0]) ? 3'd0 :
                          (th_cam[1] == id[2:0]) ? 3'd1 :
                          (th_cam[2] == id[2:0]) ? 3'd2 :
                          (th_cam[3] == id[2:0]) ? 3'd3 :
                          (th_cam[4] == id[2:0]) ? 3'd4 :
                          (th_cam[5] == id[2:0]) ? 3'd5 :
                          (th_cam[6] == id[2:0]) ? 3'd6 :
                          (th_cam[7] == id[2:0]) ? 3'd7 : 3'd7;
    end
  endgenerate

  // Combinational pair counting
  reg [4:0] count_r;
  integer c, d;

  always @* begin
    count_r = 5'd0;
    // Only camels 1..n are valid, count pairs (c,d) with 1 <= c < d <= n
    for (c = 1; c <= 8; c = c + 1) begin
      for (d = c + 1; d <= 8; d = d + 1) begin
        if ((c <= n) && (d <= n)) begin
          if ((pos_jp[c] < pos_jp[d]) &&
              (pos_jn[c] < pos_jn[d]) &&
              (pos_th[c] < pos_th[d])) begin
            count_r = count_r + 5'd1;
          end
        end
      end
    end
  end

  assign count = count_r;

endmodule