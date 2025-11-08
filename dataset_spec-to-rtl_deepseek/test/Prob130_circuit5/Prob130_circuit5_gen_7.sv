module TopModule(input [3:0] a, b, c, d, e, output logic [3:0] q);
  always_comb begin
    case (c)
      4'd0: q = b;
      4'd1: q = e;
      4'd2: q = a;
      4'd3: q = d;
      default: q = 4'hf;
    endcase
  end
endmodule