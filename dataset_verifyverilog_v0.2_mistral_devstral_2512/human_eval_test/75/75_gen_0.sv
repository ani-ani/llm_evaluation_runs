module is_multiply_prime (
  input [6:0] number,
  output is_product
);

  always @* begin
    case (number)
      8, 12, 18, 20, 27, 28, 30, 42, 44, 45, 50, 52, 63, 66, 68, 70, 75, 76, 78, 92, 98, 99, 102, 105, 110, 114, 116, 124, 125:
        is_product = 1'b1;
      default:
        is_product = 1'b0;
    endcase
  end

endmodule