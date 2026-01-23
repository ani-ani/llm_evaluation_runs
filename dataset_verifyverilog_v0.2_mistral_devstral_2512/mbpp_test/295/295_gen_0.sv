module sum_divisors (
  input [7:0] number,
  output [15:0] sum_result
);

  wire [15:0] divisor_sums [255:0];
  integer i;

  // Generate block to check all possible divisors
  genvar j;
  generate
    for (j = 1; j <= 255; j = j + 1) begin : divisor_check
      assign divisor_sums[j] = (j < number && number % j == 0) ? j : 0;
    end
  endgenerate

  // Adder tree to sum all valid divisors
  wire [15:0] sum_stage1 [128:0];
  wire [15:0] sum_stage2 [64:0];
  wire [15:0] sum_stage3 [32:0];
  wire [15:0] sum_stage4 [16:0];
  wire [15:0] sum_stage5 [8:0];
  wire [15:0] sum_stage6 [4:0];
  wire [15:0] sum_stage7 [2:0];
  wire [15:0] sum_stage8;

  // Stage 1: Sum pairs of divisors
  for (i = 0; i < 128; i = i + 1) begin
    assign sum_stage1[i] = divisor_sums[2*i] + divisor_sums[2*i+1];
  end

  // Stage 2: Sum pairs of stage1 results
  for (i = 0; i < 64; i = i + 1) begin
    assign sum_stage2[i] = sum_stage1[2*i] + sum_stage1[2*i+1];
  end

  // Stage 3: Sum pairs of stage2 results
  for (i = 0; i < 32; i = i + 1) begin
    assign sum_stage3[i] = sum_stage2[2*i] + sum_stage2[2*i+1];
  end

  // Stage 4: Sum pairs of stage3 results
  for (i = 0; i < 16; i = i + 1) begin
    assign sum_stage4[i] = sum_stage3[2*i] + sum_stage3[2*i+1];
  end

  // Stage 5: Sum pairs of stage4 results
  for (i = 0; i < 8; i = i + 1) begin
    assign sum_stage5[i] = sum_stage4[2*i] + sum_stage4[2*i+1];
  end

  // Stage 6: Sum pairs of stage5 results
  for (i = 0; i < 4; i = i + 1) begin
    assign sum_stage6[i] = sum_stage5[2*i] + sum_stage5[2*i+1];
  end

  // Stage 7: Sum pairs of stage6 results
  for (i = 0; i < 2; i = i + 1) begin
    assign sum_stage7[i] = sum_stage6[2*i] + sum_stage6[2*i+1];
  end

  // Final stage: Sum last two results
  assign sum_stage8 = sum_stage7[0] + sum_stage7[1];

  // Handle special cases (number=0 or number=1)
  assign sum_result = (number == 0 || number == 1) ? 0 : sum_stage8;

endmodule