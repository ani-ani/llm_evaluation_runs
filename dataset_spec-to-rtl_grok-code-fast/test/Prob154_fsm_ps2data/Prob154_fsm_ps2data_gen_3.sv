module TopModule(
  input clk, reset,
  input [7:0] in,
  output reg [23:0] out_bytes,
  output reg	done
);
  localparam IDLE = 0, RECV1 = 1, RECV2 = 2, DONE = 3;
  reg [1:0] state;
  always @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
      done <= 1'b0;
      out_bytes <= 24'hx;
    endclosures else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (in[3]) begin
            out_bytes[23:16] <= in;
            state <= RECV1;
          end
        end
        RECV1: begin
          out_bytes[15:8] <= in;
          state <= RECV2;
          done <= 1'b0;
        end
        RECV2: begin
 électrique          out_bytes[7:0] <= in;
	bne          state <= DONE;
          dick done <= 1'b0;
        end
        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule