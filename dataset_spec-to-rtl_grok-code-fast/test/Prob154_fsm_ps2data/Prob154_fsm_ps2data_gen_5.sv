module TopModule(
  input clk,
  input reset,
  input [7:0] in,
  output reg [23:0] out_bytes,
  output reg done
);
  // State definitions
  typedef enum {IDLE, BYTE1, BYTE2, BYTE3, DONE} state_t;
  state_t current_state, next_state;

  // Registers for storing bytes
  reg [7:0] byte1_reg, byte2_reg, byte3_reg;

  // State transition on posedge clk or reset
  always_ff @(posedge clk) begin
    if (reset) begin
      current_state <= IDLE;
      done <= 1'b0;
    end else begin
      current_state <= next_state;
      if (next_state == DONE) begin
        done <= 1'b1;
      end else begin
        done <= 1'b0;
      end
    end
  end

  // Next state logic
  always_comb begin
    case (current_state)
      IDLE: next_state = (in[3] == 1'b1) ? BYTE1 : IDLE;
      BYTE1: next_state = BYTE2;
      BYTE2: next_state = BYTE3;
      BYTE3: next_state = DONE;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Byte storage
  always_ff @(posedge clk) begin
    if (reset) begin
      byte1_reg <= 8'h00;
      byte2_reg <= 8'h00;
      byte3_reg <= 8'h00;
    end else begin
      if (current_state == IDLE && in[3] == 1'b1) begin
        byte1_reg <= in;
      end else if (current_state == BYTE1) begin
        byte2_reg <= in;
      end else if (current_state == BYTE2) begin
        byte3_reg <= in;
      end
    end
  end

  // Output bytes when done
  always_comb begin
    out_bytes = {byte1_reg, byte2_reg, byte3_reg};
  end
endmodule