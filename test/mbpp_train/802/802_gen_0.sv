module array_rotation_counter(
  input  [3:0] arr0,
  input  [3:0] arr1,
  input  [3:0] arr2,
  input  [3:0] arr3,
  input  [3:0] arr4,
  input  [3:0] arr5,
  input  [3:0] arr6,
  input  [3:0] arr7,
  input  [2:0] array_size,
  output reg [2:0] rotation_count
);

  always @* begin
    if (array_size <= 1) begin
      rotation_count = 3'd0;
    end else begin
      // Default to 0 (sorted or no rotation point found)
      rotation_count = 3'd0;

      // Check index 1
      if ((array_size > 1) && (arr1 < arr0) && (rotation_count == 3'd0)) begin
        rotation_count = 3'd1;
      end
      // Check index 2
      if ((array_size > 2) && (rotation_count == 3'd0) && (arr2 < arr1)) begin
        rotation_count = 3'd2;
      end
      // Check index 3
      if ((array_size > 3) && (rotation_count == 3'd0) && (arr3 < arr2)) begin
        rotation_count = 3'd3;
      end
      // Check index 4
      if ((array_size > 4) && (rotation_count == 3'd0) && (arr4 < arr3)) begin
        rotation_count = 3'd4;
      end
      // Check index 5
      if ((array_size > 5) && (rotation_count == 3'd0) && (arr5 < arr4)) begin
        rotation_count = 3'd5;
      end
      // Check index 6
      if ((array_size > 6) && (rotation_count == 3'd0) && (arr6 < arr5)) begin
        rotation_count = 3'd6;
      end
      // Check index 7
      if ((array_size > 7) && (rotation_count == 3'd0) && (arr7 < arr6)) begin
        rotation_count = 3'd7;
      end
    end
  end

endmodule