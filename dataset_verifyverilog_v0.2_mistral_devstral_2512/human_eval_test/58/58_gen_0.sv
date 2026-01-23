module common_elements (
  input [7:0] list1 [0:7],
  input [7:0] list2 [0:7],
  output [7:0] result [0:7],
  output [3:0] count
);

  // Step 1: Find common elements (including duplicates)
  reg [7:0] common [0:63];
  integer i, j, k, m, n;
  integer common_count = 0;

  for (i = 0; i < 8; i = i + 1) begin
    for (j = 0; j < 8; j = j + 1) begin
      if (list1[i] == list2[j]) begin
        common[common_count] = list1[i];
        common_count = common_count + 1;
      end
    end
  end

  // Step 2: Remove duplicates
  reg [7:0] unique [0:7];
  integer unique_count = 0;
  reg found;

  for (i = 0; i < common_count; i = i + 1) begin
    found = 0;
    for (j = 0; j < unique_count; j = j + 1) begin
      if (common[i] == unique[j]) begin
        found = 1;
      end
    end
    if (!found && common[i] != 0) begin
      unique[unique_count] = common[i];
      unique_count = unique_count + 1;
    end
  end

  // Step 3: Sort unique elements (bubble sort)
  reg [7:0] temp;
  for (i = 0; i < unique_count; i = i + 1) begin
    for (j = 0; j < unique_count - i - 1; j = j + 1) begin
      if (unique[j] > unique[j + 1]) begin
        temp = unique[j];
        unique[j] = unique[j + 1];
        unique[j + 1] = temp;
      end
    end
  end

  // Step 4: Assign results
  for (i = 0; i < 8; i = i + 1) begin
    if (i < unique_count) begin
      result[i] = unique[i];
    end else begin
      result[i] = 0;
    end
  end

  count = unique_count;

endmodule