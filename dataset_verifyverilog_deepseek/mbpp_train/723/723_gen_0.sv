module same_value_counter (
  input signed [5:0] list1 [0:7],
  input signed [5:0] list2 [0:7],
  output logic [3:0] count
);

  always_comb begin
    count = '0;
    for (int i = 0; i < 8; i++) begin
      if (list1[i] == list2[i]) count++;
    end
  end

endmodule