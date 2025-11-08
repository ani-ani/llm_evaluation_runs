module TopModule(
  input [254:0] in,
  output logic [7:0] out
);

  always_comb begin
    out = 8'b0;
    for (int i = 0; i < 255; i++) begin
      out = out + {7'b0, in[i]};
    end
  end

endmodule