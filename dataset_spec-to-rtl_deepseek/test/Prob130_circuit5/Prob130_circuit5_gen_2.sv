module TopModule(input reg [3:0] a,b,c,d,e, output reg [3:0] q);
  always_comb begin
    case(c)
      4'h0: q = b;
      4'h1: q = e;
      4'h2: q = a;
      4'h3: q = d;
      default: q = 4'hf;
    endcase
  end
endmodule