module extract_rear(
  input  [63:0] str0,
  input  [63:0] str1,
  input  [63:0] str2,
  input  [63:0] str3,
  input  [2:0]  len0,
  input  [2:0]  len1,
  input  [2:0]  len2,
  input  [2:0]  len3,
  output [7:0]  rear0,
  output [7:0]  rear1,
  output [7:0]  rear2,
  output [7:0]  rear3
);

  function automatic [7:0] get_rear_char(
    input [63:0] str,
    input [2:0]  len
  );
    begin
      case (len)
        3'd0: get_rear_char = 8'h00;
        3'd1: get_rear_char = str[63:56];
        3'd2: get_rear_char = str[55:48];
        3'd3: get_rear_char = str[47:40];
        3'd4: get_rear_char = str[39:32];
        3'd5: get_rear_char = str[31:24];
        3'd6: get_rear_char = str[23:16];
        3'd7: get_rear_char = str[15:8];
        default: get_rear_char = 8'h00;
      endcase
    end
  endfunction

  assign rear0 = get_rear_char(str0, len0);
  assign rear1 = get_rear_char(str1, len1);
  assign rear2 = get_rear_char(str2, len2);
  assign rear3 = get_rear_char(str3, len3);

endmodule