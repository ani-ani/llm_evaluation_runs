module count_lists(
  input wire [7:0] sublist_mask,
  output logic [3:0] count
);

  always_comb begin
    count = 4'b0;
    for (int i = 0; i < 8; i++) begin
      if (sublist_mask[i])
        count++;
    end
  end

endmodule