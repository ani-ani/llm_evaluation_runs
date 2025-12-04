module divisible_by_11 (
    input [15:0] n,
    output reg is_divisible
);

reg [3:0] d0, d1, d2, d3, d4;
reg [15:0] temp;
reg signed [7:0] alt_sum;

always @(*) begin
   temp = n;
   d0 = temp % 10;
   temp = temp / 10;
   d1 = temp % 10;
   temp = temp / 10;
   d2 = temp % 10;
   temp = temp / 10;
   d3 = temp % 10;
   temp = temp / 10;
   d4 = temp;
   alt_sum = d0;
   alt_sum = alt_sum - d1;
   alt_sum = alt_sum + d2;
   alt_sum = alt_sum - d3;
   alt_sum = alt_sum + d4;
   if (alt_sum < 0) begin
      alt_sum = -alt_sum;
   end
   if (alt_sum == 0 || alt_sum == 11 || alt_sum == 22) begin
      is_divisible = 1'b1;
   end
   else begin
      is_divisible = 1'b0;
   end
end

endmodule