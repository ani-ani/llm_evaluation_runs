module rev_checker(
  input var [7:0] num,
  output logic check
);

  // Extract decimal digits
  wire [3:0] a, b, c; // units, tens, hundreds
  assign a = num % 10;
  assign b = (num / 10) % 10;
  assign c = (num / 100) % 10;

  // Compute reversed number ignoring leading zeros
  logic [9:0] reversed_num;
  always_comb begin
    if (c != 0) reversed_num = a*100 + b*10 + c;
    else if (b != 0) reversed_num = a*10 + b;
    else reversed_num = a;
  end

  // Compute check = (2 * reversed_num == num + 1)
  logic [10:0] doubled_rev;
  always_comb begin
    doubled_rev = reversed_num * 2;
  end

  always_comb begin
    check = (doubled_rev == (num + 1));
  end

endmodule