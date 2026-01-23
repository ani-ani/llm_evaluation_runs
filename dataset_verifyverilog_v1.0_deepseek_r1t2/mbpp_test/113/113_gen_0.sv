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
  reg all_digits;
  reg all_digits_after_sign;
  reg first_is_sign;
  integer i;
  
  is_integer = 1'b0;
  all_digits = 1'b1;
  all_digits_after_sign = 1'b1;
  first_is_sign = 1'b0;
  
  if (length == 4'd0) begin
    // Empty string - invalid
    is_integer = 1'b0;
  end
  else begin
    // Check first character
    first_is_sign = is_sign(char_array[7:0]);
    
    // Check all digits case
    for (i = 0; i < 16; i = i + 1) begin
      if (i < length) begin
        if (!is_digit(char_array[i*8 +: 8])) begin
          all_digits = 1'b0;
        end
      end
    end
    
    // Check digits after sign
    if (length > 4'd0 && first_is_sign) begin
      for (i = 1; i < 16; i = i + 1) begin
        if (i < length) begin
          if (!is_digit(char_array[i*8 +: 8])) begin
            all_digits_after_sign = 1'b0;
          end
        end
      end
    end
    
    // Decision logic
    if (length == 4'd1) begin
      is_integer = is_digit(char_array[7:0]);
    end
    else if (all_digits && (length > 4'd0)) begin
      is_integer = 1'b1;
    end
    else if (first_is_sign && (length > 4'd1) && all_digits_after_sign) begin
      is_integer = 1'b1;
    end
  end
end

endmodule