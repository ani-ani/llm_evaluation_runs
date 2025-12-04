module rounded_average(input reg [7:0] n, m, output signed [8:0] result);
  wire cond = n > m;
  wire [8:0] count = m - n + 1;
  wire [8:0] n_plus_m = n + m;
  wire [17:0] product = n_plus_m * count;
  wire [16:0] shifted_product = product >> 1;
  wire [15:0] sum = shifted_product[15:0];
  wire [7:0] count_half = count[8:1];
  wire [15:0] sum_plus_half = sum + {8'b0, count_half};
  wire [15:0] divided = sum_plus_half / count;
  wire [7:0] rounded_average = divided[7:0];
  assign result = cond ? 9'sb111111111 : {1'b0, rounded_average};
endmodule