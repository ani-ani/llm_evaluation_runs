module TopModule(
  input clk,
  input reset,
  input [7:0] in,
  output [23:0] out_bytes,
  output done
);

  reg [1:0] state;
  reg done_reg;
  reg [7:0] byte1, byte2, byte3;

  assign out_bytes = {byte1, byte2, byte3};
  assign done = done_reg;

  always @(posedge clk) begin
    if (reset) begin
      state <= 2'b00;
      done_reg <= 1'b0;
      byte1 <= 8'b0;
      byte2 <= 8'b0;
      byte3 <= 8'b0;
    end else begin
      case (state)
        2'b00: begin  // idle
          done_reg <= 1'b0;
          if (in[3]) begin
            byte1 <= in;
            state <= 2'b01;
          end
        end
        2'b01: begin  // have byte1
          byte2 <= in;
          state <= 2'b10;
        end
        2'b10: begin  // have byte1 and byte2
          byte3 <= in;
          done_reg <= 1'b1;
          state <= 2'b00;
        end
      endcase
    end
  end
endmodule