module array_range_sum (
  input [127:0] array_data,
  input [3:0] start_idx,
  input [3:0] end_idx,
  output logic [11:0] range_sum
);

always_comb begin
  logic [7:0] elements [0:15];
  for (int j=0; j<16; j++) begin
    elements[j] = array_data[j*8 +:8];
  end
  range_sum = '0;
  if (start_idx <= end_idx) begin
    for (int i=0; i<16; i++) begin
      if (i >= start_idx && i <= end_idx) begin
        range_sum = range_sum + elements[i];
      end
    end
  end
end

endmodule