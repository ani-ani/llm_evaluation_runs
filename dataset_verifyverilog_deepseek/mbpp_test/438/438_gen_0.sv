module bidirectional_counter (input [15:0] tuples [0:7], output reg [4:0] count);
  logic [27:0] matches;
  localparam integer start[7] = '{0,7,13,18,22,25,27};
  genvar gi, gj;
  generate
    for (gi = 0; gi < 7; gi++) begin : gen_i
      for (gj = gi + 1; gj < 8; gj++) begin : gen_j
        localparam integer idx = start[gi] + (gj - gi - 1);
        assign matches[idx] = (tuples[gi][15:8] == tuples[gj][7:0]) && (tuples[gi][7:0] == tuples[gj][15:8]);
      end
    end
  endgenerate
  always_comb begin
    count = 0;
    for (int k = 0; k < 28; k++) begin
      count += matches[k];
    end
  end
endmodule