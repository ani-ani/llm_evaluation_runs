module list_combinations(input logic [3:0][1:0] elements, output logic [15:0][3:0] all_combinations);
  genvar i;
  generate
    for (i = 0; i < 16; i++) begin : combos
      assign all_combinations[i] = i[3:0];
    end
  endgenerate
endmodule