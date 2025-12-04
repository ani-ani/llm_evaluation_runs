module list_combinations(input [3:0][1:0] elements, output [15:0][3:0] all_combinations);
  genvar i;
  generate
    for (i=0; i<16; i=i+1) begin : gen_comb
      assign all_combinations[i] = i;
    end
  endgenerate
endmodule