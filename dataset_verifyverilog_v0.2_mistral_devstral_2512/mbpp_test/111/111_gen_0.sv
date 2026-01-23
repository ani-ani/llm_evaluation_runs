module common_in_nested_lists (
  input [7:0] list1 [0:7],
  input [7:0] list2 [0:7],
  input [7:0] list3 [0:7],
  output [63:0] common_elements,
  output [2:0] count
);

  reg [7:0] temp_common [0:7];
  reg [2:0] temp_count;
  integer i, j, k;
  reg match;
  reg already_added;

  always @* begin
    temp_count = 0;
    for (i = 0; i < 8; i = i + 1) begin
      temp_common[i] = 8'b0;
    end

    for (i = 0; i < 8; i = i + 1) begin
      match = 1'b0;
      already_added = 1'b0;

      // Check if list1[i] exists in list2
      for (j = 0; j < 8; j = j + 1) begin
        if (list1[i] == list2[j]) begin
          match = 1'b1;
          break;
        end
      end

      // Check if list1[i] exists in list3
      for (k = 0; k < 8; k = k + 1) begin
        if (list1[i] == list3[k]) begin
          match = match & 1'b1;
          break;
        end
      end

      // Check if already added to temp_common
      if (match) begin
        for (j = 0; j < temp_count; j = j + 1) begin
          if (list1[i] == temp_common[j]) begin
            already_added = 1'b1;
            break;
          end
        end

        if (!already_added) begin
          temp_common[temp_count] = list1[i];
          temp_count = temp_count + 1;
        end
      end
    end

    // Pack the results into common_elements
    common_elements = {temp_common[7], temp_common[6], temp_common[5], temp_common[4], 
                      temp_common[3], temp_common[2], temp_common[1], temp_common[0]};
    count = temp_count;
  end

endmodule