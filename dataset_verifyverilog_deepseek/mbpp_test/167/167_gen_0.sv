module next_power_of_two(input [15:0] n, output [16:0] result);
  wire [15:0] n_minus_one = n - 16'b1;
  wire is_power_of_two = (n != 16'b0) && ((n & n_minus_one) == 16'b0);
  
  logic [4:0] position;
  always_comb begin
    if (n[15]) position = 5'd15;
    else if (n[14]) position = 5'd14;
    else if (n[13]) position = 5'd13;
    else if (n[12]) position = 5'd12;
    else if (n[11]) position = 5'd11;
    else if (n[10]) position = 5'd10;
    else if (n[9]) position = 5'd9;
    else if (n[8]) position = 5'd8;
    else if (n[7]) position = 5'd7;
    else if (n[6]) position = 5'd6;
    else if (n[5]) position = 5'd5;
    else if (n[4]) position = 5'd4;
    else if (n[3]) position = 5'd3;
    else if (n[2]) position = 5'd2;
    else if (n[1]) position = 5'd1;
    else if (n[0]) position = 5'd0;
    else position = 5'd0;
  end
  
  always_comb begin
    if (n == 16'b0) result = 17'd1;
    else if (is_power_of_two) result = {1'b0, n};
    else result = 17'b1 << (position + 1);
  end
endmodule