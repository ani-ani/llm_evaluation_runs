module count_separating_roads(
  input signed [15:0] x1,
  input signed [15:0] y1,
  input signed [15:0] x2,
  input signed [15:0] y2,
  input signed [15:0] a [0:7],
  input signed [15:0] b [0:7],
  input signed [15:0] c [0:7],
  output reg [3:0] count
);

  wire [31:0] home_val [0:7];
  wire [31:0] univ_val [0:7];
  wire [7:0] opposite;

  generate
    genvar i;
    for (i=0; i<8; i=i+1) begin : road_calc
      assign home_val[i] = ($signed(a[i]) * $signed(x1)) + ($signed(b[i]) * $signed(y1)) + $signed({{16{c[i][15]}}, c[i]});
      assign univ_val[i] = ($signed(a[i]) * $signed(x2)) + ($signed(b[i]) * $signed(y2)) + $signed({{16{c[i][15]}}, c[i]});
      assign opposite[i] = home_val[i][31] ^ univ_val[i][31];
    end
  endgenerate

  always_comb begin
    count = 4'd0;
    for (int j=0; j<8; j++) begin
      count += opposite[j];
    end
  end

endmodule