module count_before_tuple (
  input [3:0][7:0] elements,
  output reg [1:0] count
);

  always_comb begin
    if (elements[0][7])       count = 2'd0;
    else if (elements[1][7])  count = 2'd1;
    else if (elements[2][7])  count = 2'd2;
    else if (elements[3][7])  count = 2'd3;
    else                      count = 2'd3;
  end

endmodule