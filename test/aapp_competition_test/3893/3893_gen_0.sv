module count_separating_roads(
  input  signed [15:0] x1,
  input  signed [15:0] y1,
  input  signed [15:0] x2,
  input  signed [15:0] y2,
  input  signed [15:0] a [0:7],
  input  signed [15:0] b [0:7],
  input  signed [15:0] c [0:7],
  output reg  [3:0]  count
);

  // Use wider intermediates to avoid overflow during multiplication and addition
  // 16-bit * 16-bit -> 32 bits; sum of three terms fits in at most 34 bits
  wire signed [31:0] home_a_mul [0:7];
  wire signed [31:0] home_b_mul [0:7];
  wire signed [31:0] univ_a_mul [0:7];
  wire signed [31:0] univ_b_mul [0:7];

  wire signed [33:0] home_value_ext [0:7];
  wire signed [33:0] univ_value_ext [0:7];

  wire               sep [0:7];

  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : road_calc
      assign home_a_mul[i] = a[i] * x1;
      assign home_b_mul[i] = b[i] * y1;
      assign univ_a_mul[i] = a[i] * x2;
      assign univ_b_mul[i] = b[i] * y2;

      // Extend c[i] to match 34-bit width
      assign home_value_ext[i] = $signed({{18{home_a_mul[i][31]}}, home_a_mul[i]}) +
                                 $signed({{18{home_b_mul[i][31]}}, home_b_mul[i]}) +
                                 $signed({{18{c[i][15]}}, c[i]});

      assign univ_value_ext[i] = $signed({{18{univ_a_mul[i][31]}}, univ_a_mul[i]}) +
                                 $signed({{18{univ_b_mul[i][31]}}, univ_b_mul[i]}) +
                                 $signed({{18{c[i][15]}}, c[i]});

      // Opposite sides if sign bits differ; zero values (exactly on road) will not assert sep
      assign sep[i] = home_value_ext[i][33] ^ univ_value_ext[i][33];
    end
  endgenerate

  always @* begin
    count = sep[0] + sep[1] + sep[2] + sep[3] +
            sep[4] + sep[5] + sep[6] + sep[7];
  end

endmodule