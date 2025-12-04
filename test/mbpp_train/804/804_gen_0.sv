module product_even_checker(
  input  [3:0][7:0] arr,
  output       is_even
);

  assign is_even = (~arr[0][0]) |
                   (~arr[1][0]) |
                   (~arr[2][0]) |
                   (~arr[3][0]);

endmodule