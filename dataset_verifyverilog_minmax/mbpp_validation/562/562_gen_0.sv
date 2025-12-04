module max_sublist_length(
  input [2:0] length1,
  input [2:0] length2,
  input [2:0] length3,
  input [2:0] length4,
  output reg [2:0] max_length
);

  logic [2:0] temp_max1;
  logic [2:0] temp_max2;

  // Step 1: Compare length1 and length2
  always_comb begin
    if (length1 > length2) begin
      temp_max1 = length1;
    end else begin
      temp_max1 = length2;
    end
  end

  // Step 2: Compare length3 and length4
  always_comb begin
    if (length3 > length4) begin
      temp_max2 = length3;
    end else begin
      temp_max2 = length4;
    end
  end

  // Step 3: Compare temp_max1 and temp_max2
  always_comb begin
    if (temp_max1 > temp_max2) begin
      max_length = temp_max1;
    end else begin
      max_length = temp_max2;
    end
  end

endmodule