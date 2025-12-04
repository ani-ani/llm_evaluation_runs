module top_n_prices(input [127:0] item_prices, input [1:0] n, output [95:0] top_prices);
  
  wire [31:0] price [3:0];
  assign price[3] = item_prices[127:96];
  assign price[2] = item_prices[95:64];
  assign price[1] = item_prices[63:32];
  assign price[0] = item_prices[31:0];
  
  wire [31:0] s1_0, s1_1, s1_2, s1_3;
  assign s1_0 = (price[0] >= price[1]) ? price[0] : price[1];
  assign s1_1 = (price[0] >= price[1]) ? price[1] : price[0];
  assign s1_2 = (price[2] >= price[3]) ? price[2] : price[3];
  assign s1_3 = (price[2] >= price[3]) ? price[3] : price[2];
  
  wire [31:0] s2_0, s2_1, s2_2, s2_3;
  assign s2_0 = (s1_0 >= s1_2) ? s1_0 : s1_2;
  assign s2_2 = (s1_0 >= s1_2) ? s1_2 : s1_0;
  assign s2_1 = (s1_1 >= s1_3) ? s1_1 : s1_3;
  assign s2_3 = (s1_1 >= s1_3) ? s1_3 : s1_1;
  
  wire [31:0] s3_1, s3_2;
  assign s3_1 = (s2_1 >= s2_2) ? s2_1 : s2_2;
  assign s3_2 = (s2_1 >= s2_2) ? s2_2 : s2_1;
  
  wire [31:0] sorted [3:0];
  assign sorted[3] = s2_0;
  assign sorted[2] = s3_1;
  assign sorted[1] = s3_2;
  assign sorted[0] = s2_3;
  
  reg [95:0] top_prices_reg;
  always_comb begin
    case(n)
      2'b00: top_prices_reg = 96'd0;
      2'b01: top_prices_reg = {sorted[3], 64'd0};
      2'b10: top_prices_reg = {sorted[3], sorted[2], 32'd0};
      2'b11: top_prices_reg = {sorted[3], sorted[2], sorted[1]};
      default: top_prices_reg = 96'd0;
    endcase
  end
  
  assign top_prices = top_prices_reg;
endmodule