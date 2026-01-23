module list_difference (
  input [7:0] list1 [0:7],
  input [7:0] list2 [0:7],
  output [7:0] difference [0:15]
);

  // Helper function to check if a value exists in a list
  function automatic [15:0] in_list;
    input [7:0] val;
    input [7:0] lst [0:7];
    integer i;
    begin
      in_list = 16'h0;
      for (i = 0; i < 8; i = i + 1) begin
        if (lst[i] == val && lst[i] != 8'hFF) begin
          in_list = 16'hFFFF;
          break;
        end
      end
    end
  endfunction

  // Check if value is in list1
  function automatic [15:0] in_list1;
    input [7:0] val;
    begin
      in_list1 = in_list(val, list1);
    end
  endfunction

  // Check if value is in list2
  function automatic [15:0] in_list2;
    input [7:0] val;
    begin
      in_list2 = in_list(val, list2);
    end
  endfunction

  // Track unique elements from list1 not in list2
  reg [7:0] unique_list1 [0:7];
  reg [7:0] unique_list2 [0:7];
  integer i, j, k, m;
  reg [7:0] temp_diff1 [0:7];
  reg [7:0] temp_diff2 [0:7];
  reg [7:0] diff1 [0:7];
  reg [7:0] diff2 [0:7];

  // Initialize temporary arrays
  for (i = 0; i < 8; i = i + 1) begin
    temp_diff1[i] = 8'hFF;
    temp_diff2[i] = 8'hFF;
    diff1[i] = 8'hFF;
    diff2[i] = 8'hFF;
  end

  // Find elements in list1 not in list2 (unique)
  k = 0;
  for (i = 0; i < 8; i = i + 1) begin
    if (list1[i] != 8'hFF && !in_list2(list1[i])) begin
      // Check if already added
      reg found;
      found = 1'b0;
      for (j = 0; j < k; j = j + 1) begin
        if (temp_diff1[j] == list1[i]) begin
          found = 1'b1;
          break;
        end
      end
      if (!found) begin
        temp_diff1[k] = list1[i];
        k = k + 1;
      end
    end
  end

  // Find elements in list2 not in list1 (unique)
  m = 0;
  for (i = 0; i < 8; i = i + 1) begin
    if (list2[i] != 8'hFF && !in_list1(list2[i])) begin
      // Check if already added
      reg found;
      found = 1'b0;
      for (j = 0; j < m; j = j + 1) begin
        if (temp_diff2[j] == list2[i]) begin
          found = 1'b1;
          break;
        end
      end
      if (!found) begin
        temp_diff2[m] = list2[i];
        m = m + 1;
      end
    end
  end

  // Copy to output arrays (maintain order)
  for (i = 0; i < 8; i = i + 1) begin
    if (i < k) begin
      diff1[i] = temp_diff1[i];
    end else begin
      diff1[i] = 8'hFF;
    end
    if (i < m) begin
      diff2[i] = temp_diff2[i];
    end else begin
      diff2[i] = 8'hFF;
    end
  end

  // Flatten the output
  for (i = 0; i < 16; i = i + 1) begin
    if (i < 8) begin
      difference[i] = diff1[i];
    end else begin
      difference[i] = diff2[i - 8];
    end
  end

endmodule