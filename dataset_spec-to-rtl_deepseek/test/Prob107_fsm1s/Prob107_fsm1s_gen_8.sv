module TopModule(input clk, input reset, input in, output out);
  reg state;

  always @(posedge clk) begin
    if (reset) begin
      state <= 1'b0;
    end else begin
      case (state)
        1'b0: state <= in ? 1'b0 : 1'b1;
        1'b1: state <= in ? 1'b1 : 1'b0;
      endcase
    end
  end

  assign out = ~state;
endmodule