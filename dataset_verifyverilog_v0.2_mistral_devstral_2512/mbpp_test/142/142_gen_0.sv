module count_samepair (
  input [7:0] list1 [0:7],
  input [7:0] list2 [0:7],
  input [7:0] list3 [0:7],
  output reg [3:0] result
);

  reg [7:0] match;
  integer i;

  always @* begin
    match = 8'b0;
    for (i = 0; i < 8; i = i + 1) begin
      match[i] = (list1[i] == list2[i]) && (list2[i] == list3[i]);
    end
    result = match[0] + match[1] + match[2] + match[3] + match[4] + match[5] + match[6] + match[7];
  end

endmodule