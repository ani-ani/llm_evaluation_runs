module sum_series(input [7:0] n, output [15:0] result);
  reg [15:0] sum;
  integer i;
  always @(*) begin
    sum = 0;
    for (i=0; i <16; i++) begin
      if (n - 2*i >0)
        sum = sum + (n - 2*i);
    end
    result = sum;
  end
endmodule