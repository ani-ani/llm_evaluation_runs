module prime_length(input [127:0] string_data, input [3:0] string_length, output is_prime);
assign is_prime = (string_length == 2 || string_length == 3 || string_length ==5 || string_length ==7 || string_length ==11 || string_length ==13);
endmodule