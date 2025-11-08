module TopModule(
  input  clk,
  input  reset,
  output shift_ena
);

  reg [2:0] count;
  reg counting;

  always @(posedge clk) begin
    if (reset) begin
      count <= 3'd0;
      counting <= 1'b1;
    end else begin
      if (counting) begin
        if (count == 3'd3) begin
          count <= 3'd0;
          counting <= 1'b0;
        end else begin
          count <= count + 1'b1;
        end
      end
    end
  end

  assign shift_ena = counting;

endmodule