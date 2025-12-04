module array_intersection (
  input [2:0] len1,
  input [2:0] len2,
  input [5:0] array1 [0:7],
  input [5:0] array2 [0:7],
  output reg [5:0] result [0:7],
  output reg [2:0] result_len
);
  reg [7:0] match_bits;
  reg [2:0] count_before [0:8];
  integer i, j;

  always_comb begin
    // Compute match_bits
    for (i = 0; i < 8; i = i + 1) begin
      match_bits[i] = 1'b0;
      if (i < len2) begin
        for (j = 0; j < 8; j = j + 1) begin
          if (j < len1 && array2[i] == array1[j]) begin
            match_bits[i] = 1'b1;
          end
        end
      end
    end

    // Compute prefix sum (count_before)
    count_before[0] = 3'b000;
    for (i = 1; i <= 8; i = i + 1) begin
      count_before[i] = count_before[i-1] + match_bits[i-1];
    end

    // Initialize result array
    for (i = 0; i < 8; i = i + 1) begin
      result[i] = 6'b000000;
    end

    // Populate result based on match_bits and count_before
    for (i = 0; i < 8; i = i + 1) begin
      if (match_bits[i]) begin
        result[count_before[i]] = array2[i];
      end
    end

    result_len = count_before[8];
  end
endmodule