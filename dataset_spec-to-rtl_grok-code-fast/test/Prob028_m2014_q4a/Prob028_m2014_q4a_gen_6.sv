module TopModule(output reg q, input d, input ena);
  always @* begin
    if (ena) q = d;
  end
endmodule