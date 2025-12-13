module prime_length_checker(
  input  [4:0] str_len,
  output       is_prime
);

  assign is_prime = (str_len == 5'd2)  ||
                    (str_len == 5'd3)  ||
                    (str_len == 5'd5)  ||
                    (str_len == 5'd7)  ||
                    (str_len == 5'd11) ||
                    (str_len == 5'd13);

endmodule