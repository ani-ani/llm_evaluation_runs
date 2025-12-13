module tree_validator(
  input  [4:0] n,
  input  [4:0] c [0:23],
  output reg   valid
);

  integer i;
  reg [4:0] max_val;
  reg has_two;

  always @* begin
    max_val = 5'd0;
    has_two = 1'b0;

    // Compute maximum and detect any value equal to 2 over c[0]..c[n-1]
    for (i = 0; i < 24; i = i + 1) begin
      if (i < n) begin
        // Track maximum value
        if (c[i] > max_val)
          max_val = c[i];
        // Check for disallowed value 2
        if (c[i] == 5'd2)
          has_two = 1'b1;
      end
    end

    // Condition 1: largest value equals n
    // Condition 2: no value equals 2
    valid = (max_val == n) && !has_two;
  end

endmodule