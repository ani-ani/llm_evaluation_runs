module filter_odd (
  input [7:0] nums [0:7],
  output [7:0] odd_nums,
  output [3:0] count
);

  integer i;
  reg [7:0] odd_nums_reg = 8'b0;
  reg [3:0] count_reg = 4'b0;

  always @* begin
    odd_nums_reg = 8'b0;
    count_reg = 4'b0;
    for (i = 0; i < 8; i = i + 1) begin
      if (nums[i][0] == 1'b1) begin
        odd_nums_reg[i] = 1'b1;
        count_reg = count_reg + 1'b1;
      end
    end
  end

  assign odd_nums = odd_nums_reg;
  assign count = count_reg;

endmodule