module tree_validator (
  input [4:0] n,
  input [4:0] c [0:23],
  output reg valid
);

  reg [4:0] c_valid [0:23];
  reg [4:0] max1 [0:11];
  reg [4:0] max2 [0:5];
  reg [4:0] max3 [0:2];
  reg [4:0] max_temp1, final_max;
  reg eq2_check [0:23];
  reg or1 [0:11];
  reg or2 [0:5];
  reg or3 [0:2];

  // Compute c_valid for each index i from 0 to 23
  for (genvar i=0; i<24; i++) begin : gen_c_valid
    always @(*) begin
      if (n > i)
        c_valid[i] = c[i];
      else
        c_valid[i] = 5'd0;
    end
  end

  // Level 1 comparators for max finder (12 comparators)
  for (genvar i=0; i<12; i++) begin : gen_level1
    always @(*) begin
      if (c_valid[2*i] > c_valid[2*i+1])
        max1[i] = c_valid[2*i];
      else
        max1[i] = c_valid[2*i+1];
    end
  end

  // Level 2 comparators for max finder (6 comparators)
  for (genvar i=0; i<6; i++) begin : gen_level2
    always @(*) begin
      if (max1[2*i] > max1[2*i+1])
        max2[i] = max1[2*i];
      else
        max2[i] = max1[2*i+1];
    end
  end

  // Level 3 comparators for max finder (3 comparators)
  for (genvar i=0; i<3; i++) begin : gen_level3
    always @(*) begin
      if (max2[2*i] > max2[2*i+1])
        max3[i] = max2[2*i];
      else
        max3[i] = max2[2*i+1];
    end
  end

  // Reduce from 3 to 1 max value (2 comparators)
  always @(*) begin
    if (max3[0] > max3[1])
      max_temp1 = max3[0];
    else
      max_temp1 = max3[1];
  end

  always @(*) begin
    if (max_temp1 > max3[2])
      final_max = max_temp1;
    else
      final_max = max3[2];
  end

  // Check for any c_valid[i] == 2
  for (genvar i=0; i<24; i++) begin : gen_eq2
    always @(*) begin
      if (c_valid[i] == 5'd2)
        eq2_check[i] = 1'b1;
      else
        eq2_check[i] = 1'b0;
    end
  end

  // OR tree for eq2_check (12 ORs)
  for (genvar i=0; i<12; i++) begin : gen_or1
    always @(*) begin
      or1[i] = eq2_check[2*i] | eq2_check[2*i+1];
    end
  end

  // OR tree for or1 (6 ORs)
  for (genvar i=0; i<6; i++) begin : gen_or2
    always @(*) begin
      or2[i] = or1[2*i] | or1[2*i+1];
    end
  end

  // OR tree for or2 (3 ORs)
  for (genvar i=0; i<3; i++) begin : gen_or3
    always @(*) begin
      or3[i] = or2[2*i] | or2[2*i+1];
    end
  end

  // Compute final valid output
  always @(*) begin
    valid = (final_max == n) && ~ (or3[0] | or3[1] | or3[2]);
  end

endmodule