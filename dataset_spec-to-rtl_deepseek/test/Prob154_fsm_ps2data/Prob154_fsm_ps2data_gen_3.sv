module TopModule (
  input clk,
  input reset,
  input [7:0] in,
  output logic [23:0] out_bytes,
  output logic done
);

  typedef enum logic [1:0] {
    S_IDLE,
    S_BYTE1,
    S_BYTE2,
    S_DONE
  } state_t;

  state_t current_state, next_state;
  reg [7:0] byte1, byte2, byte3;

  always_ff @(posedge clk) begin
    if (reset) begin
      current_state <= S_IDLE;
      byte1 <= 8'b0;
      byte2 <= 8'b0;
      byte3 <= 8'b0;
    end else begin
      current_state <= next_state;
    end
  end

  always_comb begin
    case (current_state)
      S_IDLE: next_state = in[3] ? S_BYTE1 : S_IDLE;
      S_BYTE1: next_state = S_BYTE2;
      S_BYTE2: next_state = S_DONE;
      S_DONE: next_state = S_IDLE;
      default: next_state = S_IDLE;
    endcase
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      // Reset handled in above block
    end else begin
      case (current_state)
        S_IDLE: if (in[3]) byte1 <= in;
        S_BYTE1: byte2 <= in;
        S_BYTE2: byte3 <= in;
        default: ;
      endcase
    end
  end

  assign done = (current_state == S_DONE);
  assign out_bytes = done ? {byte1, byte2, byte3} : 24'bx;

endmodule