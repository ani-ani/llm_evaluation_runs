module max_sublist_length(
  input  [2:0] length1,
  input  [2:0] length2,
  input  [2:0] length3,
  input  [2:0] length4,
  output reg [2:0] max_length
);

  reg [2:0] temp_max1;
  reg [2:0] temp_max2;

  always @(*) begin
    // Step 1: Compare length1 and length2
    if (length1 >= length2)
      temp_max1 = length1;
    else
      temp_max1 = length2;

    // Step 2: Compare length3 and length4
    if (length3 >= length4)
      temp_max2 = length3;
    else
      temp_max2 = length4;

    // Step 3: Compare temp_max1 and temp_max2
    if (temp_max1 >= temp_max2)
      max_length = temp_max1;
    else
      max_length = temp_max2;
  end

endmodule