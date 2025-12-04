module string_length (input reg [127:0] string_bytes, output reg [4:0] length);
   always_comb begin
      length = 5'b10000;
      if (string_bytes[7:0] == 8'h00)
         length = 0;
      else if (string_bytes[15:8] == 8'h00)
         length = 1;
      else if (string_bytes[23:16] == 8'h00)
         length = 2;
      else if (string_bytes[31:24] == 8'h00)
         length = 3;
      else if (string_bytes[39:32] == 8'h00)
         length = 4;
      else if (string_bytes[47:40] == 8'h00)
         length = 5;
      else if (string_bytes[55:48] == 8'h00)
         length = 6;
      else if (string_bytes[63:56] == 8'h00)
         length = 7;
      else if (string_bytes[71:64] == 8'h00)
         length = 8;
      else if (string_bytes[79:72] == 8'h00)
         length = 9;
      else if (string_bytes[87:80] == 8'h00)
         length = 10;
      else if (string_bytes[95:88] == 8'h00)
         length = 11;
      else if (string_bytes[103:96] == 8'h00)
         length = 12;
      else if (string_bytes[111:104] == 8'h00)
         length = 13;
      else if (string_bytes[119:112] == 8'h00)
         length = 14;
      else if (string_bytes[127:120] == 8'h00)
         length = 15;
   end
endmodule