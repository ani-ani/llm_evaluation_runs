module array_rotation_counter (
  input reg [3:0] arr0, arr1, arr2, arr3, arr4, arr5, arr6, arr7,
  input reg [2:0] array_size,
  output reg [2:0] rotation_count
);
  always_comb begin
    if (array_size == 3'd0 || array_size == 3'd1) begin
      rotation_count = 3'd0;
    end
    else if (arr1 < arr0) begin
      rotation_count = 3'd1;
    end
    else if (array_size >= 3 && arr2 < arr1) begin
      rotation_count = 3'd2;
    end
    else if (array_size >= 4 && arr3 < arr2) begin
      rotation_count = 3'd3;
    end
    else if (array_size >= 5 && arr4 < arr3) begin
      rotation_count = 3'd4;
    end
    else if (array_size >= 6 && arr5 < arr4) begin
      rotation_count = 3'd5;
    end
    else if (array_size >= 7 && arr6 < arr5) begin
      rotation_count = 3'd6;
    end
    else if (array_size >= 8 && arr7 < arr6) begin
      rotation_count = 3'd7;
    end
    else begin
      rotation_count = 3'd0;
    end
  end
endmodule