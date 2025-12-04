module polite_number(input [7:0] n, output [8:0] result);

  function [3:0] log2floor(input [8:0] num);
    reg [3:0] res;
    integer i;
    begin
      res = 0;
      for (i = 8; i >= 0; i = i - 1) begin
        if (num[i]) begin
          res = i;
          i = -1;
        end
      end
      log2floor = res;
    end
  endfunction

  wire [8:0] x = {1'b0, n} + 9'b1;
  wire [3:0] log1 = log2floor(x);
  wire [8:0] sum1 = x + {5'b0, log1};
  wire [3:0] log2_val = log2floor(sum1);
  assign result = x + {5'b0, log2_val};

endmodule