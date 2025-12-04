module closest_pair(input [255:0] numbers_packed, output [63:0] closest_pair);

  typedef struct packed {
    logic signed [31:0] smaller;
    logic signed [31:0] larger;
    logic signed [31:0] diff;
  } pair_t;

  localparam NUM_PAIRS = 28;
  pair_t [NUM_PAIRS-1:0] pairs;

  logic signed [31:0] e [7:0];

  assign e[0] = numbers_packed[31:0];
  assign e[1] = numbers_packed[63:32];
  assign e[2] = numbers_packed[95:64];
  assign e[3] = numbers_packed[127:96];
  assign e[4] = numbers_packed[159:128];
  assign e[5] = numbers_packed[191:160];
  assign e[6] = numbers_packed[223:192];
  assign e[7] = numbers_packed[255:224];

  genvar i, j;
  generate
    for (i=0; i<7; i++) begin : outer
      for (j=i+1; j<8; j++) begin : inner
        localparam int T = (i*(15 - i))/2;
        localparam int idx = T + (j - i - 1);
        assign pairs[idx].smaller = (e[i] < e[j]) ? e[i] : e[j];
        assign pairs[idx].larger  = (e[i] < e[j]) ? e[j] : e[i];
        assign pairs[idx].diff    = pairs[idx].larger - pairs[idx].smaller;
      end
    end
  endgenerate

  pair_t min_pair;

  always_comb begin
    min_pair = pairs[0];
    for (int k=1; k<NUM_PAIRS; k++) begin
      if (pairs[k].diff < min_pair.diff) begin
        min_pair = pairs[k];
      end else if (pairs[k].diff == min_pair.diff) begin
        if (pairs[k].smaller < min_pair.smaller) begin
          min_pair = pairs[k];
        end
      end
    end
  end

  assign closest_pair = {min_pair.smaller, min_pair.larger};

endmodule