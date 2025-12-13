module close_element_checker(
  input  [127:0] numbers_packed,  // 8 numbers, each 16-bit Q8.8
  input  [15:0]  threshold_q8_8,  // Threshold in Q8.8
  output         has_close_pair
);

  // Unpack the 8 Q8.8 numbers
  wire [15:0] n0 = numbers_packed[15:0];
  wire [15:0] n1 = numbers_packed[31:16];
  wire [15:0] n2 = numbers_packed[47:32];
  wire [15:0] n3 = numbers_packed[63:48];
  wire [15:0] n4 = numbers_packed[79:64];
  wire [15:0] n5 = numbers_packed[95:80];
  wire [15:0] n6 = numbers_packed[111:96];
  wire [15:0] n7 = numbers_packed[127:112];

  // Function to compute absolute difference between two 16-bit values
  function automatic [15:0] abs_diff;
    input [15:0] a;
    input [15:0] b;
    begin
      if (a >= b)
        abs_diff = a - b;
      else
        abs_diff = b - a;
    end
  endfunction

  // Compute all pairwise absolute differences (28 pairs)
  wire [15:0] d00_01 = abs_diff(n0, n1);
  wire [15:0] d00_02 = abs_diff(n0, n2);
  wire [15:0] d00_03 = abs_diff(n0, n3);
  wire [15:0] d00_04 = abs_diff(n0, n4);
  wire [15:0] d00_05 = abs_diff(n0, n5);
  wire [15:0] d00_06 = abs_diff(n0, n6);
  wire [15:0] d00_07 = abs_diff(n0, n7);

  wire [15:0] d01_02 = abs_diff(n1, n2);
  wire [15:0] d01_03 = abs_diff(n1, n3);
  wire [15:0] d01_04 = abs_diff(n1, n4);
  wire [15:0] d01_05 = abs_diff(n1, n5);
  wire [15:0] d01_06 = abs_diff(n1, n6);
  wire [15:0] d01_07 = abs_diff(n1, n7);

  wire [15:0] d02_03 = abs_diff(n2, n3);
  wire [15:0] d02_04 = abs_diff(n2, n4);
  wire [15:0] d02_05 = abs_diff(n2, n5);
  wire [15:0] d02_06 = abs_diff(n2, n6);
  wire [15:0] d02_07 = abs_diff(n2, n7);

  wire [15:0] d03_04 = abs_diff(n3, n4);
  wire [15:0] d03_05 = abs_diff(n3, n5);
  wire [15:0] d03_06 = abs_diff(n3, n6);
  wire [15:0] d03_07 = abs_diff(n3, n7);

  wire [15:0] d04_05 = abs_diff(n4, n5);
  wire [15:0] d04_06 = abs_diff(n4, n6);
  wire [15:0] d04_07 = abs_diff(n4, n7);

  wire [15:0] d05_06 = abs_diff(n5, n6);
  wire [15:0] d05_07 = abs_diff(n5, n7);

  wire [15:0] d06_07 = abs_diff(n6, n7);

  // Compare each difference against threshold: condition is diff < threshold
  wire c00_01 = (d00_01 < threshold_q8_8);
  wire c00_02 = (d00_02 < threshold_q8_8);
  wire c00_03 = (d00_03 < threshold_q8_8);
  wire c00_04 = (d00_04 < threshold_q8_8);
  wire c00_05 = (d00_05 < threshold_q8_8);
  wire c00_06 = (d00_06 < threshold_q8_8);
  wire c00_07 = (d00_07 < threshold_q8_8);

  wire c01_02 = (d01_02 < threshold_q8_8);
  wire c01_03 = (d01_03 < threshold_q8_8);
  wire c01_04 = (d01_04 < threshold_q8_8);
  wire c01_05 = (d01_05 < threshold_q8_8);
  wire c01_06 = (d01_06 < threshold_q8_8);
  wire c01_07 = (d01_07 < threshold_q8_8);

  wire c02_03 = (d02_03 < threshold_q8_8);
  wire c02_04 = (d02_04 < threshold_q8_8);
  wire c02_05 = (d02_05 < threshold_q8_8);
  wire c02_06 = (d02_06 < threshold_q8_8);
  wire c02_07 = (d02_07 < threshold_q8_8);

  wire c03_04 = (d03_04 < threshold_q8_8);
  wire c03_05 = (d03_05 < threshold_q8_8);
  wire c03_06 = (d03_06 < threshold_q8_8);
  wire c03_07 = (d03_07 < threshold_q8_8);

  wire c04_05 = (d04_05 < threshold_q8_8);
  wire c04_06 = (d04_06 < threshold_q8_8);
  wire c04_07 = (d04_07 < threshold_q8_8);

  wire c05_06 = (d05_06 < threshold_q8_8);
  wire c05_07 = (d05_07 < threshold_q8_8);

  wire c06_07 = (d06_07 < threshold_q8_8);

  assign has_close_pair =
       c00_01 | c00_02 | c00_03 | c00_04 | c00_05 | c00_06 | c00_07 |
       c01_02 | c01_03 | c01_04 | c01_05 | c01_06 | c01_07 |
       c02_03 | c02_04 | c02_05 | c02_06 | c02_07 |
       c03_04 | c03_05 | c03_06 | c03_07 |
       c04_05 | c04_06 | c04_07 |
       c05_06 | c05_07 |
       c06_07;

endmodule