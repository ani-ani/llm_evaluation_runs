module list_sum (
  input [7:0] elements [7:0],
  input [7:0] valid_mask,
  output logic [15:0] total_sum
);

  always_comb begin
    total_sum = 16'd0;
    for (int i = 0; i < 8; i++) begin
      if (valid_mask[i]) begin
        total_sum += elements[i];
      end
    end
  end

endmodule