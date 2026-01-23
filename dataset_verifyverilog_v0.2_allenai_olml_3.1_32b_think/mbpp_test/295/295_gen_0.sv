module sum_divisors(input [7:0] number, output [15:0] sum_result);
always_comb
sum_result = 0;
for (int i=1; i < number; i++) begin
if (number % i == 0) 
sum_result += i;
end
endmodule