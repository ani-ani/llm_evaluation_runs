module max_digit_sum(
  input reg [15:0] n,
  output wire [6:0] max_sum
);

  reg [15:0] a_val;
  reg [6:0] digit_sum_a;
  wire [15:0] b_val = n - a_val;

  wire [3:0] digit0 = b_val % 10;
  wire [3:0] digit1 = (b_val / 10) % 10;
  wire [3:0] digit2 = (b_val / 100) % 10;
  wire [3:0] digit3 = (b_val / 1000) % 10;
  wire [3:0] digit4 = (b_val / 10000) % 10;

  wire [6:0] digit_sum_b = digit0 + digit1 + digit2 + digit3 + digit4;

  assign max_sum = digit_sum_a + digit_sum_b;

  always_comb begin
    if (n >= 10000) begin
      a_val = 16'd9999;
      digit_sum_a = 7'd36;
    end else if (n >= 1000) begin
      a_val = 16'd999;
      digit_sum_a = 7'd27;
    end else if (n >= 100) begin
      a_val = 16'd99;
      digit_sum_a = 7'd18;
    end else if (n >= 10) begin
      a_val = 16'd9;
      digit_sum_a = 7'd9;
    end else begin
      a_val = 16'd0;
      digit_sum_a = 7'd0;
    end
  end

endmodule