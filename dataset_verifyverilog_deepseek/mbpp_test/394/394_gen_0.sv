module check_distinct (
  input [7:0] tuple [7:0],
  output wire is_distinct
);

  reg any_dup;

  always_comb begin
    any_dup = 1'b0;
    for (int i = 1; i < 8; i++) begin
      for (int j = 0; j < i; j++) begin
        any_dup = any_dup | (tuple[i] == tuple[j]);
      end
    end
  end

  assign is_distinct = ~any_dup;

endmodule