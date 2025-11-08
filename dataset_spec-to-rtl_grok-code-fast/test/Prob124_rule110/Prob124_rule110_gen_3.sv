module TopModule(
  input clk,
  input load,
  input [511:0] data,
  output logic [511:0] q
);

  always_ff @(posedge clk) begin
    if (load) begin
      q <= data;
    end else begin
      for (int i = 0; i < 512; i++) begin
        logic left = (i > 0) ? q[i-1] : 1'b0;
        logic cent = q[i];
        logic rigt = (i < 511) ? q[i+1] : 1'b0;
        logic next_cent;
        case ({left, cent, rigt})
          3'b000: next_cent = 1'b0;
          3'b001: next_cent = 1'b1;
          3'b010: next_cent = 1'b1;
          3'b011: next_cent = 1'b1;
          3'b100: next_cent = 1'b0;
          3'b101: next_cent = 1'b1;
          3'b110: next_cent = 1'b1;
          3'b111: next_cent = 1'b0;
          default: next_cent = 1'b0;
        endcase
        q[i] <= next_cent;
      end
    end
  end

endmodule