module array_intersection (
  input [7:0] array1 [0:7],
  input [7:0] array2 [0:7],
  input [2:0] len1,
  input [2:0] len2,
  output [7:0] result [0:7],
  output [7:0] result_valid
);

  parameter N = 8;

  // Step 1: For each array2 element, check if it exists in array1
  logic [7:0] match [0:7];
  for (int i = 0; i < N; i = i + 1) begin : gen_match
    for (int j = 0; j < N; j = j + 1) begin : gen_match_bits
      assign match[i][j] = (array2[i] == array1[j]) && (j < len1);
    end
  end

  // Step 2: Determine which array2 elements are valid (exist in array1 and within len2)
  logic [7:0] elem_valid;
  for (int i = 0; i < N; i = i + 1) begin : gen_elem_valid
    assign elem_valid[i] = (|match[i]) && (i < len2);
  end

  // Step 3: Pack valid elements into result array in order
  logic [7:0] packed_result [0:7];
  logic [7:0] packed_valid;
  logic [7:0] count = 0;

  for (int i = 0; i < N; i = i + 1) begin : gen_pack
    if (elem_valid[i]) begin
      assign packed_result[count] = array2[i];
      assign packed_valid[count] = 1'b1;
      assign count = count + 1;
    end
  end

  // Assign outputs
  assign result = packed_result;
  assign result_valid = packed_valid;

endmodule