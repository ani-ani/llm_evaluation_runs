module count_element (
  input [63:0] array_data,
  input [3:0] target,
  output logic [3:0] count
);

  always_comb begin
    count = 4'b0;
    for (int i=0; i<12; i=i+1) begin
      if (array_data[i*4 +:4] == target) begin
        count = count + 4'b1;
      end
    end
  end

endmodule