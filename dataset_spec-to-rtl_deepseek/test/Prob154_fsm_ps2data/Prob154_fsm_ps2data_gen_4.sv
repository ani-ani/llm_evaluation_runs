module TopModule (
  input  clk,
  input  reset,
  input  [7:0] in,
  output reg [23:0] out_bytes,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    BYTE1,
    BYTE2,
    DONE
  } state_t;

  state_t state;
  reg [7:0] byte1_reg, byte2_reg, byte3_reg;

  always_ff @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
      done <= 0;
      byte1_reg <= 0;
      byte2_reg <= 0;
      byte3_reg <= 0;
      out_bytes <= 24'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (in[3]) begin
            state <= BYTE1;
            byte1_reg <= in;
          end
        end
        BYTE1: begin
          state <= BYTE2;
          byte2_reg <= in;
        end
        BYTE2: begin
          state <= DONE;
          byte3_reg <= in;
        end
        DONE: begin
          out_bytes <= {byte1_reg, byte2_reg, byte3_reg};
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule