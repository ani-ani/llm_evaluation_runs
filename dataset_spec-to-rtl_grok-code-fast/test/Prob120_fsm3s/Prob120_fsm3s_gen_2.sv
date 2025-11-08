module TopModule(input clk, input reset, input in, output out);
  reg [1:0] state;
  always @(posedge clk) begin
    if(reset) state <= 2'b00;
    else begin
      case(state)
        2'b00: if(in) state <= 2'b01; else state <= 2'b00;
        2'b01: if(in) state <= 2'b01; else state <= 2'b10;
        2'b10: if(in) state <= 2'b11; else state <= 2'b00;
        2'b11: if(in) state <= 2'b01; else state <= 2'b10;
      endcase
    end
  end
  assign out = (state == 2'b11);
endmodule