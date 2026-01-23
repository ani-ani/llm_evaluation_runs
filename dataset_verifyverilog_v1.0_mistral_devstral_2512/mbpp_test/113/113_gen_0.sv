module string_is_integer(
  input [127:0] char_array,
  input [3:0] length,
  output reg is_integer
);

  function automatic is_digit(input [7:0] c);
    begin
      is_digit = (c >= 8'd48) && (c <= 8'd57);
    end
  endfunction

  function automatic is_sign(input [7:0] c);
    begin
      is_sign = (c == 8'd43) || (c == 8'd45);
    end
  endfunction

  always @(*) begin
    is_integer = 1'b0;
    
    if (length == 4'd0) begin
      is_integer = 1'b0;
    end else if (length == 4'd1) begin
      if (is_digit(char_array[7:0])) begin
        is_integer = 1'b1;
      end
    end else begin
      reg all_digits;
      reg all_digits_after_sign;
      reg first_is_sign;
      integer i;
      
      all_digits = 1'b1;
      for (i = 0; i < 16; i = i + 1) begin
        if (i < length) begin
          if (!is_digit(char_array[i*8 +: 8])) all_digits = 1'b0;
        end
      end
      
      first_is_sign = is_sign(char_array[7:0]);
      
      all_digits_after_sign = 1'b1;
      for (i = 1; i < 16; i = i + 1) begin
        if (i < length) begin
          if (!is_digit(char_array[i*8 +: 8])) all_digits_after_sign = 1'b0;
        end
      end
      
      if (all_digits) begin
        is_integer = 1'b1;
      end else if (first_is_sign && all_digits_after_sign) begin
        is_integer = 1'b1;
      end
    end
  end

endmodule