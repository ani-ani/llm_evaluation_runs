module dict_empty_check (
  input [8:0] entries [0:7],
  output logic empty_flag
);

  always_comb begin
    empty_flag = 1'b1;
    for (int i = 0; i < 8; i++) begin
      if (entries[i][8]) begin
        empty_flag = 1'b0;
      end
    end
  end

endmodule