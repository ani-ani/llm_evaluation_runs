module unsorted_perm_count(
  input  [2:0] n,      // Sequence length (1-8)
  output reg [31:0] count  // Number of unsorted permutations
);

  always @* begin
    case (n)
      3'd1: count = 32'd0;
      3'd2: count = 32'd0;
      3'd3: count = 32'd2;
      3'd4: count = 32'd14;
      3'd5: count = 32'd90;
      3'd6: count = 32'd646;
      3'd7: count = 32'd5242;
      3'd8: count = 32'd47622;
      default: count = 32'd0;
    endcase
  end

endmodule