module max_digit_sum(
  input [15:0] n,
  output [6:0] max_sum
);

  reg [2:0] L;
  reg [15:0] a;
  reg [15:0] b;
  reg [6:0] digit_sum_a;
  reg [6:0] digit_sum_b;

  always @(*) begin
    if (n < 10)
      L = 1;
    else if (n < 100)
      L = 2;
    else if (n < 1000)
      L = 3;
    else if (n < 10000)
      L = 4;
    else
      L = 5;
  end

  always @(*) begin
    case (L)
      3'd1: a = 16'd0;
      3'd2: a = 16'd9;
      3'd3: a = 16'd99;
      3'd4: a = 16'd999;
      3'd5: a = 16'd9999;
      default: a = 16'd0;
    endcase
  end

  assign b = n - a;

  always @(*) begin
    digit_sum_a = (L - 1) * 9;
  end

  always @(*) begin
    digit_sum_b = (b % 10) 
                + ((b / 10) % 10)
                + ((b / 100) % 10)
                + ((b / 1000) % 10)
                + ((b / 10000) % 10);
  end

  assign max_sum = digit_sum_a + digit_sum_b;

endmodule