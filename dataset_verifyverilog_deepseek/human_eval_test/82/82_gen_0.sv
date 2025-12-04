module prime_length_checker(input [4:0] str_len, output logic is_prime);
  always_comb begin
    case(str_len)
      5'd2, 5'd3, 5'd5, 5'd7, 5'd11, 5'd13: is_prime = 1'b1;
      default: is_prime = 1'b0;
    endcase
  end
endmodule