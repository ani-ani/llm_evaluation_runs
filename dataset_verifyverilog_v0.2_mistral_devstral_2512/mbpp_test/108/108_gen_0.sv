module merge_three_sorted_lists (
  input [7:0] list1_size,
  input [7:0] list2_size,
  input [7:0] list3_size,
  input [2:0][7:0] list1,
  input [2:0][7:0] list2,
  input [2:0][7:0] list3,
  output reg [5:0] result_size,
  output reg [23:0][7:0] result
);

  reg [2:0] ptr1 = 0, ptr2 = 0, ptr3 = 0;
  reg [5:0] i = 0;
  reg [7:0] min_val;
  reg [1:0] min_src;

  always @* begin
    result_size = list1_size + list2_size + list3_size;

    for (i = 0; i < 24; i = i + 1) begin
      if (i < result_size) begin
        // Determine current elements (treat empty lists as infinity)
        min_val = (ptr1 < list1_size) ? list1[ptr1] : 8'hFF;
        min_src = 0;

        if ((ptr2 < list2_size) && (list2[ptr2] < min_val)) begin
          min_val = list2[ptr2];
          min_src = 1;
        end

        if ((ptr3 < list3_size) && (list3[ptr3] < min_val)) begin
          min_val = list3[ptr3];
          min_src = 2;
        end

        // Store the minimum value
        result[i] = min_val;

        // Advance the pointer for the selected list
        case (min_src)
          0: ptr1 = ptr1 + 1;
          1: ptr2 = ptr2 + 1;
          2: ptr3 = ptr3 + 1;
        endcase
      end else begin
        result[i] = 8'h0; // Fill remaining positions with 0
      end
    end
  end

endmodule