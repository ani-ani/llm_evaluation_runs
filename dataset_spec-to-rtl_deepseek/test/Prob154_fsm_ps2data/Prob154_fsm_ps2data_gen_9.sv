module TopModule (
  input clk,
  input reset,
  input [7:0] in,
  output [23:0] out_bytes,
  output done
);

  localparam IDLE         = 2'b00;
  localparam COLLECT_SECOND = 2'b01;
  localparam COLLECT_THIRD  = 2'b10;
  localparam ASSERT_DONE    = 2'b11;

  reg [1:0] state;
  reg [7:0] byte1_reg;
  reg [7:0] byte2_reg;
  reg [7:0] byte3_reg;

  assign out_bytes = {byte1_reg, byte2_reg, byte3_reg};
  assign done = (state == ASSERT_DONE);

  always @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
      byte1_reg <= 8'h0;
      byte2_reg <= 8'h0;
      byte3_reg <= 8'h0;
    end else begin
      case (state)
        IDLE: begin
          if (in[3] == 1'b1) begin
            byte1_reg <= in;
            state <= COLLECT_SECOND;
          end
        end
        COLLECT_SECOND: begin
          byte2_reg <= in;
          state <= COLLECT_THIRD;
        end
        COLLECT_THIRD: begin
          byte3_reg <= in;
          state <= ASSERT_DONE;
        end
        ASSERT_DONE: begin
          state <= IDLE;
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule