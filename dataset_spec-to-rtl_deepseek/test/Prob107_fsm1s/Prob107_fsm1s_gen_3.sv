module TopModule(input clk, input reset, input in, output out);
  localparam STATE_A = 1'b0;
  localparam STATE_B = 1'b1;
  
  reg state;
  
  assign out = (state == STATE_B);
  
  always @(posedge clk) begin
    if (reset)
      state <= STATE_B;
    else
      case (state)
        STATE_B: state <= in ? STATE_B : STATE_A;
        STATE_A: state <= in ? STATE_A : STATE_B;
        default: state <= STATE_B;
      endcase
  end
endmodule