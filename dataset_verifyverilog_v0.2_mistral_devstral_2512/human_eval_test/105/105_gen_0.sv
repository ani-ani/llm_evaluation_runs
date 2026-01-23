module by_length (
  input [7:0] arr0, arr1, arr2, arr3, arr4, arr5, arr6, arr7,
  output [7:0] out0_char0, out0_char1, out0_char2, out0_char3, out0_char4,
  output [7:0] out1_char0, out1_char1, out1_char2, out1_char3, out1_char4,
  output [7:0] out2_char0, out2_char1, out2_char2, out2_char3, out2_char4,
  output [7:0] out3_char0, out3_char1, out3_char2, out3_char3, out3_char4,
  output [7:0] out4_char0, out4_char1, out4_char2, out4_char3, out4_char4,
  output [7:0] out5_char0, out5_char1, out5_char2, out5_char3, out5_char4,
  output [7:0] out6_char0, out6_char1, out6_char2, out6_char3, out6_char4,
  output [7:0] out7_char0, out7_char1, out7_char2, out7_char3, out7_char4,
  output [3:0] count
);

  // String mappings (5 bytes each)
  localparam [7:0] ONE [0:4] = '{8'o117, 8'o156, 8'o105, 8'o40, 8'o40};
  localparam [7:0] TWO [0:4] = '{8'o124, 8'o167, 8'o157, 8'o40, 8'o40};
  localparam [7:0] THREE [0:4] = '{8'o124, 8'o150, 8'o162, 8'o105, 8'o105};
  localparam [7:0] FOUR [0:4] = '{8'o106, 8'o157, 8'o165, 8'o162, 8'o40};
  localparam [7:0] FIVE [0:4] = '{8'o106, 8'o151, 8'o166, 8'o105, 8'o40};
  localparam [7:0] SIX [0:4] = '{8'o123, 8'o151, 8'o170, 8'o40, 8'o40};
  localparam [7:0] SEVEN [0:4] = '{8'o123, 8'o105, 8'o166, 8'o105, 8'o155};
  localparam [7:0] EIGHT [0:4] = '{8'o105, 8'o151, 8'o147, 8'o150, 8'o164};
  localparam [7:0] NINE [0:4] = '{8'o116, 8'o151, 8'o156, 8'o105, 8'o40};

  // Filter and collect valid digits (1-9)
  reg [7:0] filtered [0:7];
  reg [3:0] valid_count = 0;

  always @* begin
    valid_count = 0;
    if (arr0 >= 1 && arr0 <= 9) begin
      filtered[valid_count] = arr0;
      valid_count = valid_count + 1;
    end
    if (arr1 >= 1 && arr1 <= 9) begin
      filtered[valid_count] = arr1;
      valid_count = valid_count + 1;
    end
    if (arr2 >= 1 && arr2 <= 9) begin
      filtered[valid_count] = arr2;
      valid_count = valid_count + 1;
    end
    if (arr3 >= 1 && arr3 <= 9) begin
      filtered[valid_count] = arr3;
      valid_count = valid_count + 1;
    end
    if (arr4 >= 1 && arr4 <= 9) begin
      filtered[valid_count] = arr4;
      valid_count = valid_count + 1;
    end
    if (arr5 >= 1 && arr5 <= 9) begin
      filtered[valid_count] = arr5;
      valid_count = valid_count + 1;
    end
    if (arr6 >= 1 && arr6 <= 9) begin
      filtered[valid_count] = arr6;
      valid_count = valid_count + 1;
    end
    if (arr7 >= 1 && arr7 <= 9) begin
      filtered[valid_count] = arr7;
      valid_count = valid_count + 1;
    end
  end

  // Sort the filtered array (bubble sort)
  reg [7:0] sorted [0:7];
  integer i, j;
  reg [7:0] temp;

  always @* begin
    for (i = 0; i < 8; i = i + 1) begin
      sorted[i] = filtered[i];
    end
    for (i = 0; i < valid_count - 1; i = i + 1) begin
      for (j = 0; j < valid_count - i - 1; j = j + 1) begin
        if (sorted[j] > sorted[j + 1]) begin
          temp = sorted[j];
          sorted[j] = sorted[j + 1];
          sorted[j + 1] = temp;
        end
      end
    end
  end

  // Reverse the sorted array
  reg [7:0] reversed [0:7];

  always @* begin
    for (i = 0; i < 8; i = i + 1) begin
      reversed[i] = sorted[valid_count - 1 - i];
    end
  end

  // Map to strings and assign outputs
  always @* begin
    count = valid_count;
    
    // Default: all spaces
    out0_char0 = 8'o40; out0_char1 = 8'o40; out0_char2 = 8'o40; out0_char3 = 8'o40; out0_char4 = 8'o40;
    out1_char0 = 8'o40; out1_char1 = 8'o40; out1_char2 = 8'o40; out1_char3 = 8'o40; out1_char4 = 8'o40;
    out2_char0 = 8'o40; out2_char1 = 8'o40; out2_char2 = 8'o40; out2_char3 = 8'o40; out2_char4 = 8'o40;
    out3_char0 = 8'o40; out3_char1 = 8'o40; out3_char2 = 8'o40; out3_char3 = 8'o40; out3_char4 = 8'o40;
    out4_char0 = 8'o40; out4_char1 = 8'o40; out4_char2 = 8'o40; out4_char3 = 8'o40; out4_char4 = 8'o40;
    out5_char0 = 8'o40; out5_char1 = 8'o40; out5_char2 = 8'o40; out5_char3 = 8'o40; out5_char4 = 8'o40;
    out6_char0 = 8'o40; out6_char1 = 8'o40; out6_char2 = 8'o40; out6_char3 = 8'o40; out6_char4 = 8'o40;
    out7_char0 = 8'o40; out7_char1 = 8'o40; out7_char2 = 8'o40; out7_char3 = 8'o40; out7_char4 = 8'o40;
    
    // Assign based on reversed array
    if (valid_count > 0) begin
      case (reversed[0])
        1: {out0_char0, out0_char1, out0_char2, out0_char3, out0_char4} = ONE;
        2: {out0_char0, out0_char1, out0_char2, out0_char3, out0_char4} = TWO;
        3: {out0_char0, out0_char1, out0_char2, out0_char3, out0_char4} = THREE;
        4: {out0_char0, out0_char1, out0_char2, out0_char3, out0_char4} = FOUR;
        5: {out0_char0, out0_char1, out0_char2, out0_char3, out0_char4} = FIVE;
        6: {out0_char0, out0_char1, out0_char2, out0_char3, out0_char4} = SIX;
        7: {out0_char0, out0_char1, out0_char2, out0_char3, out0_char4} = SEVEN;
        8: {out0_char0, out0_char1, out0_char2, out0_char3, out0_char4} = EIGHT;
        9: {out0_char0, out0_char1, out0_char2, out0_char3, out0_char4} = NINE;
      endcase
    end
    if (valid_count > 1) begin
      case (reversed[1])
        1: {out1_char0, out1_char1, out1_char2, out1_char3, out1_char4} = ONE;
        2: {out1_char0, out1_char1, out1_char2, out1_char3, out1_char4} = TWO;
        3: {out1_char0, out1_char1, out1_char2, out1_char3, out1_char4} = THREE;
        4: {out1_char0, out1_char1, out1_char2, out1_char3, out1_char4} = FOUR;
        5: {out1_char0, out1_char1, out1_char2, out1_char3, out1_char4} = FIVE;
        6: {out1_char0, out1_char1, out1_char2, out1_char3, out1_char4} = SIX;
        7: {out1_char0, out1_char1, out1_char2, out1_char3, out1_char4} = SEVEN;
        8: {out1_char0, out1_char1, out1_char2, out1_char3, out1_char4} = EIGHT;
        9: {out1_char0, out1_char1, out1_char2, out1_char3, out1_char4} = NINE;
      endcase
    end
    if (valid_count > 2) begin
      case (reversed[2])
        1: {out2_char0, out2_char1, out2_char2, out2_char3, out2_char4} = ONE;
        2: {out2_char0, out2_char1, out2_char2, out2_char3, out2_char4} = TWO;
        3: {out2_char0, out2_char1, out2_char2, out2_char3, out2_char4} = THREE;
        4: {out2_char0, out2_char1, out2_char2, out2_char3, out2_char4} = FOUR;
        5: {out2_char0, out2_char1, out2_char2, out2_char3, out2_char4} = FIVE;
        6: {out2_char0, out2_char1, out2_char2, out2_char3, out2_char4} = SIX;
        7: {out2_char0, out2_char1, out2_char2, out2_char3, out2_char4} = SEVEN;
        8: {out2_char0, out2_char1, out2_char2, out2_char3, out2_char4} = EIGHT;
        9: {out2_char0, out2_char1, out2_char2, out2_char3, out2_char4} = NINE;
      endcase
    end
    if (valid_count > 3) begin
      case (reversed[3])
        1: {out3_char0, out3_char1, out3_char2, out3_char3, out3_char4} = ONE;
        2: {out3_char0, out3_char1, out3_char2, out3_char3, out3_char4} = TWO;
        3: {out3_char0, out3_char1, out3_char2, out3_char3, out3_char4} = THREE;
        4: {out3_char0, out3_char1, out3_char2, out3_char3, out3_char4} = FOUR;
        5: {out3_char0, out3_char1, out3_char2, out3_char3, out3_char4} = FIVE;
        6: {out3_char0, out3_char1, out3_char2, out3_char3, out3_char4} = SIX;
        7: {out3_char0, out3_char1, out3_char2, out3_char3, out3_char4} = SEVEN;
        8: {out3_char0, out3_char1, out3_char2, out3_char3, out3_char4} = EIGHT;
        9: {out3_char0, out3_char1, out3_char2, out3_char3, out3_char4} = NINE;
      endcase
    end
    if (valid_count > 4) begin
      case (reversed[4])
        1: {out4_char0, out4_char1, out4_char2, out4_char3, out4_char4} = ONE;
        2: {out4_char0, out4_char1, out4_char2, out4_char3, out4_char4} = TWO;
        3: {out4_char0, out4_char1, out4_char2, out4_char3, out4_char4} = THREE;
        4: {out4_char0, out4_char1, out4_char2, out4_char3, out4_char4} = FOUR;
        5: {out4_char0, out4_char1, out4_char2, out4_char3, out4_char4} = FIVE;
        6: {out4_char0, out4_char1, out4_char2, out4_char3, out4_char4} = SIX;
        7: {out4_char0, out4_char1, out4_char2, out4_char3, out4_char4} = SEVEN;
        8: {out4_char0, out4_char1, out4_char2, out4_char3, out4_char4} = EIGHT;
        9: {out4_char0, out4_char1, out4_char2, out4_char3, out4_char4} = NINE;
      endcase
    end
    if (valid_count > 5) begin
      case (reversed[5])
        1: {out5_char0, out5_char1, out5_char2, out5_char3, out5_char4} = ONE;
        2: {out5_char0, out5_char1, out5_char2, out5_char3, out5_char4} = TWO;
        3: {out5_char0, out5_char1, out5_char2, out5_char3, out5_char4} = THREE;
        4: {out5_char0, out5_char1, out5_char2, out5_char3, out5_char4} = FOUR;
        5: {out5_char0, out5_char1, out5_char2, out5_char3, out5_char4} = FIVE;
        6: {out5_char0, out5_char1, out5_char2, out5_char3, out5_char4} = SIX;
        7: {out5_char0, out5_char1, out5_char2, out5_char3, out5_char4} = SEVEN;
        8: {out5_char0, out5_char1, out5_char2, out5_char3, out5_char4} = EIGHT;
        9: {out5_char0, out5_char1, out5_char2, out5_char3, out5_char4} = NINE;
      endcase
    end
    if (valid_count > 6) begin
      case (reversed[6])
        1: {out6_char0, out6_char1, out6_char2, out6_char3, out6_char4} = ONE;
        2: {out6_char0, out6_char1, out6_char2, out6_char3, out6_char4} = TWO;
        3: {out6_char0, out6_char1, out6_char2, out6_char3, out6_char4} = THREE;
        4: {out6_char0, out6_char1, out6_char2, out6_char3, out6_char4} = FOUR;
        5: {out6_char0, out6_char1, out6_char2, out6_char3, out6_char4} = FIVE;
        6: {out6_char0, out6_char1, out6_char2, out6_char3, out6_char4} = SIX;
        7: {out6_char0, out6_char1, out6_char2, out6_char3, out6_char4} = SEVEN;
        8: {out6_char0, out6_char1, out6_char2, out6_char3, out6_char4} = EIGHT;
        9: {out6_char0, out6_char1, out6_char2, out6_char3, out6_char4} = NINE;
      endcase
    end
    if (valid_count > 7) begin
      case (reversed[7])
        1: {out7_char0, out7_char1, out7_char2, out7_char3, out7_char4} = ONE;
        2: {out7_char0, out7_char1, out7_char2, out7_char3, out7_char4} = TWO;
        3: {out7_char0, out7_char1, out7_char2, out7_char3, out7_char4} = THREE;
        4: {out7_char0, out7_char1, out7_char2, out7_char3, out7_char4} = FOUR;
        5: {out7_char0, out7_char1, out7_char2, out7_char3, out7_char4} = FIVE;
        6: {out7_char0, out7_char1, out7_char2, out7_char3, out7_char4} = SIX;
        7: {out7_char0, out7_char1, out7_char2, out7_char3, out7_char4} = SEVEN;
        8: {out7_char0, out7_char1, out7_char2, out7_char3, out7_char4} = EIGHT;
        9: {out7_char0, out7_char1, out7_char2, out7_char3, out7_char4} = NINE;
      endcase
    end
  end

endmodule