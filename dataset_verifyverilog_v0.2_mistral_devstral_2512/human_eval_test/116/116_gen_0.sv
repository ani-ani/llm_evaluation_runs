module sort_array (
  input [7:0] in_0, in_1, in_2, in_3, in_4, in_5, in_6, in_7,
  output [7:0] out_0, out_1, out_2, out_3, out_4, out_5, out_6, out_7
);

  // Popcount function for 8-bit input
  function [2:0] popcount;
    input [7:0] val;
    begin
      popcount = val[0] + val[1] + val[2] + val[3] + val[4] + val[5] + val[6] + val[7];
    end
  endfunction

  // Comparator function
  function [1:0] compare;
    input [7:0] a, b;
    begin
      if (popcount(a) < popcount(b)) begin
        compare = 2'b00; // a < b
      end else if (popcount(a) > popcount(b)) begin
        compare = 2'b11; // a > b
      end else begin
        if (a < b) begin
          compare = 2'b00; // a < b
        end else if (a > b) begin
          compare = 2'b11; // a > b
        end else begin
          compare = 2'b10; // a == b
        end
      end
    end
  endfunction

  // Initial array
  reg [7:0] arr [0:7];
  always @* begin
    arr[0] = in_0;
    arr[1] = in_1;
    arr[2] = in_2;
    arr[3] = in_3;
    arr[4] = in_4;
    arr[5] = in_5;
    arr[6] = in_6;
    arr[7] = in_7;
  end

  // Odd-even transposition sort network (28 stages)
  reg [7:0] temp_arr [0:7];
  integer i, j;

  // Stage 1: Odd-even pairs
  always @* begin
    for (i = 0; i < 8; i = i + 1) begin
      temp_arr[i] = arr[i];
    end
    // Odd pairs (1-2, 3-4, 5-6)
    if (compare(temp_arr[1], temp_arr[2]) == 2'b11) begin
      temp_arr[1] = arr[2];
      temp_arr[2] = arr[1];
    end
    if (compare(temp_arr[3], temp_arr[4]) == 2'b11) begin
      temp_arr[3] = arr[4];
      temp_arr[4] = arr[3];
    end
    if (compare(temp_arr[5], temp_arr[6]) == 2'b11) begin
      temp_arr[5] = arr[6];
      temp_arr[6] = arr[5];
    end
    // Even pairs (0-1, 2-3, 4-5, 6-7)
    if (compare(temp_arr[0], temp_arr[1]) == 2'b11) begin
      temp_arr[0] = arr[1];
      temp_arr[1] = arr[0];
    end
    if (compare(temp_arr[2], temp_arr[3]) == 2'b11) begin
      temp_arr[2] = arr[3];
      temp_arr[3] = arr[2];
    end
    if (compare(temp_arr[4], temp_arr[5]) == 2'b11) begin
      temp_arr[4] = arr[5];
      temp_arr[5] = arr[4];
    end
    if (compare(temp_arr[6], temp_arr[7]) == 2'b11) begin
      temp_arr[6] = arr[7];
      temp_arr[7] = arr[6];
    end
    for (i = 0; i < 8; i = i + 1) begin
      arr[i] = temp_arr[i];
    end
  end

  // Stage 2: Odd-even pairs
  always @* begin
    for (i = 0; i < 8; i = i + 1) begin
      temp_arr[i] = arr[i];
    end
    // Odd pairs (1-2, 3-4, 5-6)
    if (compare(temp_arr[1], temp_arr[2]) == 2'b11) begin
      temp_arr[1] = arr[2];
      temp_arr[2] = arr[1];
    end
    if (compare(temp_arr[3], temp_arr[4]) == 2'b11) begin
      temp_arr[3] = arr[4];
      temp_arr[4] = arr[3];
    end
    if (compare(temp_arr[5], temp_arr[6]) == 2'b11) begin
      temp_arr[5] = arr[6];
      temp_arr[6] = arr[5];
    end
    // Even pairs (0-1, 2-3, 4-5, 6-7)
    if (compare(temp_arr[0], temp_arr[1]) == 2'b11) begin
      temp_arr[0] = arr[1];
      temp_arr[1] = arr[0];
    end
    if (compare(temp_arr[2], temp_arr[3]) == 2'b11) begin
      temp_arr[2] = arr[3];
      temp_arr[3] = arr[2];
    end
    if (compare(temp_arr[4], temp_arr[5]) == 2'b11) begin
      temp_arr[4] = arr[5];
      temp_arr[5] = arr[4];
    end
    if (compare(temp_arr[6], temp_arr[7]) == 2'b11) begin
      temp_arr[6] = arr[7];
      temp_arr[7] = arr[6];
    end
    for (i = 0; i < 8; i = i + 1) begin
      arr[i] = temp_arr[i];
    end
  end

  // Stage 3: Odd-even pairs
  always @* begin
    for (i = 0; i < 8; i = i + 1) begin
      temp_arr[i] = arr[i];
    end
    // Odd pairs (1-2, 3-4, 5-6)
    if (compare(temp_arr[1], temp_arr[2]) == 2'b11) begin
      temp_arr[1] = arr[2];
      temp_arr[2] = arr[1];
    end
    if (compare(temp_arr[3], temp_arr[4]) == 2'b11) begin
      temp_arr[3] = arr[4];
      temp_arr[4] = arr[3];
    end
    if (compare(temp_arr[5], temp_arr[6]) == 2'b11) begin
      temp_arr[5] = arr[6];
      temp_arr[6] = arr[5];
    end
    // Even pairs (0-1, 2-3, 4-5, 6-7)
    if (compare(temp_arr[0], temp_arr[1]) == 2'b11) begin
      temp_arr[0] = arr[1];
      temp_arr[1] = arr[0];
    end
    if (compare(temp_arr[2], temp_arr[3]) == 2'b11) begin
      temp_arr[2] = arr[3];
      temp_arr[3] = arr[2];
    end
    if (compare(temp_arr[4], temp_arr[5]) == 2'b11) begin
      temp_arr[4] = arr[5];
      temp_arr[5] = arr[4];
    end
    if (compare(temp_arr[6], temp_arr[7]) == 2'b11) begin
      temp_arr[6] = arr[7];
      temp_arr[7] = arr[6];
    end
    for (i = 0; i < 8; i = i + 1) begin
      arr[i] = temp_arr[i];
    end
  end

  // Stage 4: Odd-even pairs
  always @* begin
    for (i = 0; i < 8; i = i + 1) begin
      temp_arr[i] = arr[i];
    end
    // Odd pairs (1-2, 3-4, 5-6)
    if (compare(temp_arr[1], temp_arr[2]) == 2'b11) begin
      temp_arr[1] = arr[2];
      temp_arr[2] = arr[1];
    end
    if (compare(temp_arr[3], temp_arr[4]) == 2'b11) begin
      temp_arr[3] = arr[4];
      temp_arr[4] = arr[3];
    end
    if (compare(temp_arr[5], temp_arr[6]) == 2'b11) begin
      temp_arr[5] = arr[6];
      temp_arr[6] = arr[5];
    end
    // Even pairs (0-1, 2-3, 4-5, 6-7)
    if (compare(temp_arr[0], temp_arr[1]) == 2'b11) begin
      temp_arr[0] = arr[1];
      temp_arr[1] = arr[0];
    end
    if (compare(temp_arr[2], temp_arr[3]) == 2'b11) begin
      temp_arr[2] = arr[3];
      temp_arr[3] = arr[2];
    end
    if (compare(temp_arr[4], temp_arr[5]) == 2'b11) begin
      temp_arr[4] = arr[5];
      temp_arr[5] = arr[4];
    end
    if (compare(temp_arr[6], temp_arr[7]) == 2'b11) begin
      temp_arr[6] = arr[7];
      temp_arr[7] = arr[6];
    end
    for (i = 0; i < 8; i = i + 1) begin
      arr[i] = temp_arr[i];
    end
  end

  // Stage 5: Odd-even pairs
  always @* begin
    for (i = 0; i < 8; i = i + 1) begin
      temp_arr[i] = arr[i];
    end
    // Odd pairs (1-2, 3-4, 5-6)
    if (compare(temp_arr[1], temp_arr[2]) == 2'b11) begin
      temp_arr[1] = arr[2];
      temp_arr[2] = arr[1];
    end
    if (compare(temp_arr[3], temp_arr[4]) == 2'b11) begin
      temp_arr[3] = arr[4];
      temp_arr[4] = arr[3];
    end
    if (compare(temp_arr[5], temp_arr[6]) == 2'b11) begin
      temp_arr[5] = arr[6];
      temp_arr[6] = arr[5];
    end
    // Even pairs (0-1, 2-3, 4-5, 6-7)
    if (compare(temp_arr[0], temp_arr[1]) == 2'b11) begin
      temp_arr[0] = arr[1];
      temp_arr[1] = arr[0];
    end
    if (compare(temp_arr[2], temp_arr[3]) == 2'b11) begin
      temp_arr[2] = arr[3];
      temp_arr[3] = arr[2];
    end
    if (compare(temp_arr[4], temp_arr[5]) == 2'b11) begin
      temp_arr[4] = arr[5];
      temp_arr[5] = arr[4];
    end
    if (compare(temp_arr[6], temp_arr[7]) == 2'b11) begin
      temp_arr[6] = arr[7];
      temp_arr[7] = arr[6];
    end
    for (i = 0; i < 8; i = i + 1) begin
      arr[i] = temp_arr[i];
    end
  end

  // Stage 6: Odd-even pairs
  always @* begin
    for (i = 0; i < 8; i = i + 1) begin
      temp_arr[i] = arr[i];
    end
    // Odd pairs (1-2, 3-4, 5-6)
    if (compare(temp_arr[1], temp_arr[2]) == 2'b11) begin
      temp_arr[1] = arr[2];
      temp_arr[2] = arr[1];
    end
    if (compare(temp_arr[3], temp_arr[4]) == 2'b11) begin
      temp_arr[3] = arr[4];
      temp_arr[4] = arr[3];
    end
    if (compare(temp_arr[5], temp_arr[6]) == 2'b11) begin
      temp_arr[5] = arr[6];
      temp_arr[6] = arr[5];
    end
    // Even pairs (0-1, 2-3, 4-5, 6-7)
    if (compare(temp_arr[0], temp_arr[1]) == 2'b11) begin
      temp_arr[0] = arr[1];
      temp_arr[1] = arr[0];
    end
    if (compare(temp_arr[2], temp_arr[3]) == 2'b11) begin
      temp_arr[2] = arr[3];
      temp_arr[3] = arr[2];
    end
    if (compare(temp_arr[4], temp_arr[5]) == 2'b11) begin
      temp_arr[4] = arr[5];
      temp_arr[5] = arr[4];
    end
    if (compare(temp_arr[6], temp_arr[7]) == 2'b11) begin
      temp_arr[6] = arr[7];
      temp_arr[7] = arr[6];
    end
    for (i = 0; i < 8; i = i + 1) begin
      arr[i] = temp_arr[i];
    end
  end

  // Stage 7: Odd-even pairs
  always @* begin
    for (i = 0; i < 8; i = i + 1) begin
      temp_arr[i] = arr[i];
    end
    // Odd pairs (1-2, 3-4, 5-6)
    if (compare(temp_arr[1], temp_arr[2]) == 2'b11) begin
      temp_arr[1] = arr[2];
      temp_arr[2] = arr[1];
    end
    if (compare(temp_arr[3], temp_arr[4]) == 2'b11) begin
      temp_arr[3] = arr[4];
      temp_arr[4] = arr[3];
    end
    if (compare(temp_arr[5], temp_arr[6]) == 2'b11) begin
      temp_arr[5] = arr[6];
      temp_arr[6] = arr[5];
    end
    // Even pairs (0-1, 2-3, 4-5, 6-7)
    if (compare(temp_arr[0], temp_arr[1]) == 2'b11) begin
      temp_arr[0] = arr[1];
      temp_arr[1] = arr[0];
    end
    if (compare(temp_arr[2], temp_arr[3]) == 2'b11) begin
      temp_arr[2] = arr[3];
      temp_arr[3] = arr[2];
    end
    if (compare(temp_arr[4], temp_arr[5]) == 2'b11) begin
      temp_arr[4] = arr[5];
      temp_arr[5] = arr[4];
    end
    if (compare(temp_arr[6], temp_arr[7]) == 2'b11) begin
      temp_arr[6] = arr[7];
      temp_arr[7] = arr[6];
    end
    for (i = 0; i < 8; i = i + 1) begin
      arr[i] = temp_arr[i];
    end
  end

  // Output assignment
  assign out_0 = arr[0];
  assign out_1 = arr[1];
  assign out_2 = arr[2];
  assign out_3 = arr[3];
  assign out_4 = arr[4];
  assign out_5 = arr[5];
  assign out_6 = arr[6];
  assign out_7 = arr[7];

endmodule