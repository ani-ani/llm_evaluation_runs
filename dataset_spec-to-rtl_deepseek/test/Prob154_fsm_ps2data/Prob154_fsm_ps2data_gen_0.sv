module TopModule (input clk, input reset, input [7:0] in, output reg [23:0] out_bytes, output reg done);

  typedef enum {IDLE, BYTE2, BYTE3, DONE} state_t;
  state_t curr_state, next_state;

  reg [7:0] byte1_reg, byte2_reg, byte3_reg;

  always_ff @(posedge clk) begin
    if (reset) begin
      curr_state <= IDLE;
      byte1_reg <= 8'h0;
      byte2_reg <= 8'h0;
      byte3_reg <= 8'h0;
    end else begin
      curr_state <= next_state;
      case (curr_state)
        IDLE: if (in[3] & next_state == BYTE2) byte1_reg <= in;
        BYTE2: byte2_reg <= in;
        BYTE3: byte3_reg <= in;
        default: ;
      endcase
    end
  end

  always_comb begin
    next_state = curr_state;
    done = 1'b0;
    case (curr_state)
      IDLE: next_state = (in[3]) ? BYTE2 : IDLE;
      BYTE2: next_state = BYTE3;
      BYTE3: next_state = DONE;
      DONE: begin
        next_state = IDLE;
        done = 1'b1;
      end
      default: next_state = IDLE;
    endcase
  end

  assign out_bytes = {byte1_reg, byte2_reg, byte3_reg};

endmodule