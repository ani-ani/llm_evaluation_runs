module list_char_compare (
  input reg [63:0] lst1,
  input reg [63:0] lst2,
  output reg [7:0] total1,
  output reg [7:0] total2,
  output reg list_sel
);

  function [7:0] sum_bytes(input [63:0] packed_bytes);
    integer i;
    begin
      sum_bytes = 8'b0;
      for (i = 0; i < 8; i = i + 1) begin
        sum_bytes = sum_bytes + packed_bytes[(i+1)*8-1 -: 8];
      end
    end
  endfunction

  always @(*) begin
    total1 = sum_bytes(lst1);
    total2 = sum_bytes(lst2);
    list_sel = (total2 < total1) ? 1'b1 : 1'b0; // tie -> lst1
  end

endmodule