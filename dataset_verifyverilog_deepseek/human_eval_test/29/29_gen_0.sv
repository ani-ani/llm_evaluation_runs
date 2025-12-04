module string_filter(input [255:0] strings_flat, input [63:0] prefix, input [2:0] prefix_len, output [3:0] match_mask);
  wire [63:0] string0 = strings_flat[63:0];
  wire [63:0] string1 = strings_flat[127:64];
  wire [63:0] string2 = strings_flat[191:128];
  wire [63:0] string3 = strings_flat[255:192];

  wire [63:0] mask = (prefix_len == 3'd0) ? 64'h0 :
                     (prefix_len == 3'd1) ? 64'hFF00000000000000 :
                     (prefix_len == 3'd2) ? 64'hFFFF000000000000 :
                     (prefix_len == 3'd3) ? 64'hFFFFFF0000000000 :
                     (prefix_len == 3'd4) ? 64'hFFFFFFFF00000000 :
                     (prefix_len == 3'd5) ? 64'hFFFFFFFFFF000000 :
                     (prefix_len == 3'd6) ? 64'hFFFFFFFFFFFF0000 :
                     (prefix_len == 3'd7) ? 64'hFFFFFFFFFFFFFF00 : 64'h0;

  wire match0 = (prefix_len == 3'd0) || ((string0 & mask) == (prefix & mask));
  wire match1 = (prefix_len == 3'd0) || ((string1 & mask) == (prefix & mask));
  wire match2 = (prefix_len == 3'd0) || ((string2 & mask) == (prefix & mask));
  wire match3 = (prefix_len == 3'd0) || ((string3 & mask) == (prefix & mask));

  assign match_mask = {match3, match2, match1, match0};
endmodule