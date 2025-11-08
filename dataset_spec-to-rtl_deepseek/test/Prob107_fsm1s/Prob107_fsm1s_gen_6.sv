module TopModule(input clk, input reset, input in, output out);
  reg state; // 0=A, 1=B (reset state)
  
  always_ff @(posedge clk) begin
    if (reset) begin
      state <= 1'b1;
    end else begin
      case (state)
        1'b0: state <= in ? 1'b0 : 1'b1; // A -> A (in=1), B (in=0)
        1'b1: state <= in ? 1'b1 : 1'b0; // B -> B (in=1), A (in=0)
        default: state <= 1'b1;
      endcase
    end
  end
  
  assign out = state; // Moore output (1 when B, 0 when A)
endmodule