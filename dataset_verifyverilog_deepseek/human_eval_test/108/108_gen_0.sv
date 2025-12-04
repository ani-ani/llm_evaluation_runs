module count_positive_digit_sums(input [7:0] arr [0:7], output reg [3:0] count);
  logic [7:0] is_positive;
  
  function automatic logic signed [4:0] compute_digit_sum(input [7:0] num_val);
    logic signed [7:0] signed_num = $signed(num_val);
    logic is_negative = (signed_num < 0);
    logic [7:0] abs_value = is_negative ? -signed_num : signed_num;
    logic [3:0] hundreds;
    logic [3:0] tens;
    logic [3:0] units;
    logic [7:0] remainder;
    hundreds = (abs_value >= 100) ? 4'd1 : 4'd0;
    remainder = abs_value - (hundreds * 100);
    tens = remainder / 10;
    units = remainder - (tens * 10);
    compute_digit_sum = (is_negative ? -$signed(hundreds) : $signed(hundreds)) + $signed(tens) + $signed(units);
  endfunction
  
  always_comb begin
    for (int i=0; i<8; i++) begin
      automatic logic signed [4:0] sum = compute_digit_sum(arr[i]);
      is_positive[i] = (sum > 0);
    end
  end
  
  always_comb begin
    count = '0;
    for (int i=0; i<8; i++) begin
      count += is_positive[i];
    end
  end
endmodule