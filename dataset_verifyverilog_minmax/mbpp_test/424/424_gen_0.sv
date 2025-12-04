module extract_rear (
  input  [63:0] str0, str1, str2, str3,
  input  [2:0]  len0, len1, len2, len3,
  output [7:0]  rear0, rear1, rear2, rear3
);

  function [7:0] get_rear;
    input [63:0] s;
    input [2:0]  l;
    begin
      if (l == 3'd0)        get_rear = 8'd0;
      else if (l == 3'd1)   get_rear = s[7:0];
      else if (l == 3'd2)   get_rear = s[15:8];
      else if (l == 3'd3)   get_rear = s[23:16];
      else if (l == 3'd4)   get_rear = s[31:24];
      else if (l == 3'd5)   get_rear = s[39:32];
      else if (l == 3'd6)   get_rear = s[47:40];
      else                  get_rear = s[55:48]; // l == 3'd7 (larger lengths clamp to last char)
    end
  endfunction

  assign rear0 = get_rear(str0, len0);
  assign rear1 = get_rear(str1, len1);
  assign rear2 = get_rear(str2, len2);
  assign rear3 = get_rear(str3, len3);

endmodule