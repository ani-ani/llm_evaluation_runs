module same_value_counter (
  input reg signed [5:0] list1 [0:7],
  input reg signed [5:0] list2 [0:7],
  output reg [3:0] count
);

  always @(*) begin
    count = 4'd0;
    for (int i = 0; i < 8; i = i + 1) begin
      if (list1[i] == list2[i]) count = count + 1;
    end
  end

endmodule