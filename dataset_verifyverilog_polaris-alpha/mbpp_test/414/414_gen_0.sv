module overlapping_checker(
  input  [7:0][3:0] list1,
  input  [7:0][3:0] list2,
  output reg        overlap
);

  integer i, j;

  always @(*) begin
    overlap = 1'b0;
    for (i = 0; i < 8; i = i + 1) begin
      for (j = 0; j < 8; j = j + 1) begin
        if (list1[i] == list2[j]) begin
          overlap = 1'b1;
        end
      end
    end
  end

endmodule