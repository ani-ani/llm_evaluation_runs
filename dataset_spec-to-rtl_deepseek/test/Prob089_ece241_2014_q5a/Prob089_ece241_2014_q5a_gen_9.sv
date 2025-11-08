module TopModule(input clk, areset, x, output z);
  reg state;
  localparam COPY = 1'b0;
  localparam COMPLEMENT = 1'b1;

  always @(posedge clk or posedge areset) begin
    if (areset) begin
      state <= COPY;
    end else begin
      case(state)
        COPY: state <= x ? COMPLEMENT : COPY;
        COMPLEMENT: state <= COMPLEMENT;
      endcase
    end
  end

  assign z = (state == COPY) ? x : ~x;
endmodule