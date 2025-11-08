module TopModule(input reg [1:0] A,
                input reg [1:0] B,
                output z);
  assign z = (A == B);
endmodule