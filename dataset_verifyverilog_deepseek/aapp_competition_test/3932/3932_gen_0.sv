module tree_validator(input [4:0] n, input [4:0] c [0:23], output reg valid);
  reg [4:0] masked_c [0:23];
  integer i;
  always @(*) begin
    for (i = 0; i < 24; i = i + 1) begin
      masked_c[i] = (i < n) ? c[i] : 5'b0;
    end
  end

  reg [4:0] max_val;
  integer j;
  always @(*) begin
    max_val = masked_c[0];
    for (j = 1; j < 24; j = j + 1) begin
      if (masked_c[j] > max_val) begin
        max_val = masked_c[j];
      end
    end
  end

  reg found_two;
  integer k;
  always @(*) begin
    found_two = 1'b0;
    for (k = 0; k < 24; k = k + 1) begin
      if (masked_c[k] == 5'd2) begin
        found_two = 1'b1;
      end
    end
  end

  always @(*) begin
    valid = (max_val == n) && !found_two;
  end
endmodule