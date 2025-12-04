module common_index_elements(
  input [7:0] l1 [0:7],
  input [7:0] l2 [0:7],
  input [7:0] l3 [0:7],
  output reg [7:0] result [0:7],
  output reg [3:0] count
);
  integer i;
  always @(*) begin
    for (i = 0; i < 8; i = i + 1) result[i] = 8'b0;
    count = 0;
    for (i = 0; i < 8; i = i + 1) begin
      if (l1[i] == l2[i] && l2[i] == l3[i]) begin
        result[count] = l1[i];
        count = count + 1;
      end
    end
  end
endmodule