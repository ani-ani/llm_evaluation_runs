module TopModule(
  input clk,
  input reset,
  input [7:0] in,
  output reg [23:0] out_bytes,
  output reg done
);

  // State encoding
  typedef enum reg [1:0] {
    IDLE = 2'b00,
    BYTE1 = 2'b01,
    BYTE2 = 2'b10,
    BYTE3 = 2'b11
  } state_t;

  state_t state, next_state;

  // Registers to store the three bytes
  reg [7:0] byte1, byte2, byte3;
  reg [7:0] next_byte1, next_byte2, next_byte3;

  // State transition logic
  always_comb begin
    next_state = state;
    next_byte1 = byte1;
    next_byte2 = byte2;
    next_byte3 = byte3;
    done = 1'b0;
    out_bytes = 24'bx;

    case (state)
      IDLE: begin
        if (in[3] == 1'b1) begin
          next_state = BYTE1;
          next_byte1 = in;
        end
      end

      BYTE1: begin
        next_state = BYTE2;
        next_byte2 = in;
      end

      BYTE2: begin
        next_state = BYTE3;
        next_byte3 = in;
      end

      BYTE3: begin
        done = 1'b1;
        out_bytes = {byte1, byte2, byte3};
        if (in[3] == 1'b1) begin
          next_state = BYTE1;
          next_byte1 = in;
        end else begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // State and data registers
  always_ff @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
      byte1 <= 8'b0;
      byte2 <= 8'b0;
      byte3 <= 8'b0;
    end else begin
      state <= next_state;
      byte1 <= next_byte1;
      byte2 <= next_byte2;
      byte3 <= next_byte3;
    end
  end

endmodule