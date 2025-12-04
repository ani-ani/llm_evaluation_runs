module distinct_check(input [7:0] arr [0:7], output logic result);
  wire [7:0] eq;
  genvar i;
  generate
    for (i=0; i<8; i=i+1) begin : gen_eq
      assign eq[i] = (arr[i] == arr[0]);
    end
  endgenerate
  assign result = &eq;
endmodule