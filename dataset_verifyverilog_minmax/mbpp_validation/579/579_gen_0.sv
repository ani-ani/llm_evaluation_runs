module dissimilar_elements (
  input [5:0] t1_0, t1_1, t1_2, t1_3,
  input [5:0] t2_0, t2_1, t2_2, t2_3,
  output [5:0] dissimilar [0:7],
  output [7:0] valid_mask
);

  // Function to check if value is present in array (for up to 8 elements)
  function automatic is_in_array;
    input [5:0] val;
    input [5:0] arr [0:7];
    input [7:0] mask;
    integer i;
  begin
    is_in_array = 1'b0;
    for (i = 0; i < 8; i = i + 1) begin
      if (mask[i] && arr[i] == val) begin
        is_in_array = 1'b1;
        disable is_in_array;
      end
    end
  end
  endfunction

  // Intermediate signals for combinational logic
  reg [5:0] arr_t1 [0:7];
  reg [5:0] arr_t2 [0:7];
  reg [7:0] mask_t1, mask_t2;

  // Initialize arrays to avoid unintended latches
  initial begin
    arr_t1[0] = t1_0; arr_t1[1] = t1_1; arr_t1[2] = t1_2; arr_t1[3] = t1_3;
    arr_t1[4] = 6'b0;  arr_t1[5] = 6'b0;  arr_t1[6] = 6'b0;  arr_t1[7] = 6'b0;
    arr_t2[0] = t2_0; arr_t2[1] = t2_1; arr_t2[2] = t2_2; arr_t2[3] = t2_3;
    arr_t2[4] = 6'b0;  arr_t2[5] = 6'b0;  arr_t2[6] = 6'b0;  arr_t2[7] = 6'b0;
    mask_t1 = 8'b00001111;
    mask_t2 = 8'b00001111;
  end

  // Build presence masks and pack tuples into arrays for membership tests
  integer idx1, idx2;
  always @* begin
    // Default to empty
    mask_t1 = 8'b0;
    mask_t2 = 8'b0;

    // Build mask for tuple1 (ensure unique elements in t1)
    for (idx1 = 0; idx1 < 4; idx1 = idx1 + 1) begin
      case (idx1)
        0: if (!is_in_array(t1_0, arr_t1, mask_t1)) begin mask_t1[0] = 1'b1; arr_t1[0] = t1_0; end
        1: if (!is_in_array(t1_1, arr_t1, mask_t1)) begin mask_t1[1] = 1'b1; arr_t1[1] = t1_1; end
        2: if (!is_in_array(t1_2, arr_t1, mask_t1)) begin mask_t1[2] = 1'b1; arr_t1[2] = t1_2; end
        3: if (!is_in_array(t1_3, arr_t1, mask_t1)) begin mask_t1[3] = 1'b1; arr_t1[3] = t1_3; end
      endcase
    end
    arr_t1[4] = 6'b0; arr_t1[5] = 6'b0; arr_t1[6] = 6'b0; arr_t1[7] = 6'b0;

    // Build mask for tuple2 (ensure unique elements in t2)
    for (idx2 = 0; idx2 < 4; idx2 = idx2 + 1) begin
      case (idx2)
        0: if (!is_in_array(t2_0, arr_t2, mask_t2)) begin mask_t2[0] = 1'b1; arr_t2[0] = t2_0; end
        1: if (!is_in_array(t2_1, arr_t2, mask_t2)) begin mask_t2[1] = 1'b1; arr_t2[1] = t2_1; end
        2: if (!is_in_array(t2_2, arr_t2, mask_t2)) begin mask_t2[2] = 1'b1; arr_t2[2] = t2_2; end
        3: if (!is_in_array(t2_3, arr_t2, mask_t2)) begin mask_t2[3] = 1'b1; arr_t2[3] = t2_3; end
      endcase
    end
    arr_t2[4] = 6'b0; arr_t2[5] = 6'b0; arr_t2[6] = 6'b0; arr_t2[7] = 6'b0;
  end

  // Compute symmetric difference: elements in t1 not in t2, or in t2 not in t1
  integer j;
  reg [5:0] temp_diss [0:7];
  reg [7:0] temp_mask;

  always @* begin
    // Default outputs
    for (j = 0; j < 8; j = j + 1) begin
      dissimilar[j] = 6'b0;
    end
    valid_mask = 8'b0;

    // Temporary result and mask
    temp_mask = 8'b0;
    temp_diss[0] = 6'b0; temp_diss[1] = 6'b0; temp_diss[2] = 6'b0; temp_diss[3] = 6'b0;
    temp_diss[4] = 6'b0; temp_diss[5] = 6'b0; temp_diss[6] = 6'b0; temp_diss[7] = 6'b0;

    // Elements in t1 not present in t2
    for (j = 0; j < 8; j = j + 1) begin
      if (mask_t1[j] && !is_in_array(arr_t1[j], arr_t2, mask_t2) && !is_in_array(arr_t1[j], temp_diss, temp_mask)) begin
        temp_diss[$unsigned(temp_mask)] = arr_t1[j];
        temp_mask[temp_mask] = 1'b1;
      end
    end

    // Elements in t2 not present in t1
    for (j = 0; j < 8; j = j + 1) begin
      if (mask_t2[j] && !is_in_array(arr_t2[j], arr_t1, mask_t1) && !is_in_array(arr_t2[j], temp_diss, temp_mask)) begin
        temp_diss[$unsigned(temp_mask)] = arr_t2[j];
        temp_mask[temp_mask] = 1'b1;
      end
    end

    // Assign final outputs
    dissimilar <= temp_diss;
    valid_mask <= temp_mask;
  end

endmodule