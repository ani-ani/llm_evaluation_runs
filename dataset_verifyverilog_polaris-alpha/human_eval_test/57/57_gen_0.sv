module monotonic_check (
  input  [2:0]      length,
  input  signed [7:0] arr [7:0],
  output            is_monotonic
);

  wire [6:0] le_pair;
  wire [6:0] ge_pair;

  genvar i;
  generate
    for (i = 0; i < 7; i = i + 1) begin : gen_pairs
      assign le_pair[i] = ($signed(arr[i]) <= $signed(arr[i+1]));
      assign ge_pair[i] = ($signed(arr[i]) >= $signed(arr[i+1]));
    end
  endgenerate

  wire incr_ok;
  wire decr_ok;

  assign incr_ok = (length <= 1) ? 1'b1 :
                   (length == 2) ? le_pair[0] :
                   (length == 3) ? (&le_pair[1:0]) :
                   (length == 4) ? (&le_pair[2:0]) :
                   (length == 5) ? (&le_pair[3:0]) :
                   (length == 6) ? (&le_pair[4:0]) :
                   (length == 7) ? (&le_pair[5:0]) :
                                   (&le_pair[6:0]);

  assign decr_ok = (length <= 1) ? 1'b1 :
                   (length == 2) ? ge_pair[0] :
                   (length == 3) ? (&ge_pair[1:0]) :
                   (length == 4) ? (&ge_pair[2:0]) :
                   (length == 5) ? (&ge_pair[3:0]) :
                   (length == 6) ? (&ge_pair[4:0]) :
                   (length == 7) ? (&ge_pair[5:0]) :
                                   (&ge_pair[6:0]);

  assign is_monotonic = (length == 0) ? 1'b0 : (incr_ok | decr_ok);

endmodule