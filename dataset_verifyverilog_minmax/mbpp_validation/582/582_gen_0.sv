module dict_empty_check (
  input  [8:0] entries [0:7],
  output logic empty_flag
);

  always_comb begin
    automatic logic any_valid;
    any_valid = 1'b0;
    for (int i = 0; i < 8; i++) begin
      any_valid |= entries[i][8];
    end
    empty_flag = ~any_valid;
  end

endmodule
