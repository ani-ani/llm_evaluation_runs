module list_difference(
  input  [3:0] list1 [0:3],
  input  [3:0] list2 [0:3],
  input  [0:3] valid1,
  input  [0:3] valid2,
  output logic [3:0] result [0:7],
  output logic [3:0] size
);

  // Internal wires for membership flags
  logic l1_in_l2 [0:3];
  logic l2_in_l1 [0:3];

  genvar i, j;

  // For each element in list1, determine if it exists in any valid element of list2
  generate
    for (i = 0; i < 4; i++) begin : GEN_L1_IN_L2
      logic match_any;
      always @* begin
        match_any = 1'b0;
        if (valid1[i]) begin
          for (j = 0; j < 4; j++) begin
            if (valid2[j] && (list1[i] == list2[j])) begin
              match_any = 1'b1;
            end
          end
        end
      end
      assign l1_in_l2[i] = match_any;
    end
  endgenerate

  // For each element in list2, determine if it exists in any valid element of list1
  generate
    for (i = 0; i < 4; i++) begin : GEN_L2_IN_L1
      logic match_any;
      always @* begin
        match_any = 1'b0;
        if (valid2[i]) begin
          for (j = 0; j < 4; j++) begin
            if (valid1[j] && (list2[i] == list1[j])) begin
              match_any = 1'b1;
            end
          end
        end
      end
      assign l2_in_l1[i] = match_any;
    end
  endgenerate

  // Collect symmetric difference into result[] using simple combinational packing
  always @* begin
    integer idx;
    integer k;
    idx = 0;

    // Initialize result
    for (k = 0; k < 8; k++) begin
      result[k] = 4'b0000;
    end

    // Elements from list1 that are valid and NOT found in list2
    for (k = 0; k < 4; k++) begin
      if (valid1[k] && !l1_in_l2[k]) begin
        result[idx] = list1[k];
        idx = idx + 1;
      end
    end

    // Elements from list2 that are valid and NOT found in list1
    for (k = 0; k < 4; k++) begin
      if (valid2[k] && !l2_in_l1[k]) begin
        result[idx] = list2[k];
        idx = idx + 1;
      end
    end

    size = idx[3:0];
  end

endmodule