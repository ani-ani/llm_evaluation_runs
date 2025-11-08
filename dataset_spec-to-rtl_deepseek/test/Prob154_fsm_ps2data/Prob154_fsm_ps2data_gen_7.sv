module TopModule(input clk, input reset, input [7:0] in, output [23:0] out_bytes, output done);
  typedef enum logic [1:0] {IDLE, B1, B2, B3} state_t;
  state_t current_state, next_state;
  reg [7:0] byte1, byte2, byte3;
  
  always_ff @(posedge clk) begin
    if (reset) begin
      current_state <= IDLE;
      byte1 <= '0;
      byte2 <= '0;
      byte3 <= '0;
    end else begin
      current_state <= next_state;
      case (current_state)
        IDLE: if (next_state == B1) byte1 <= in;
        B1: byte2 <= in;
        B2: byte3 <= in;
        default: ;
      endcase
    end
  end
  
  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: if (in[3]) next_state = B1;
      B1: next_state = B2;
      B2: next_state = B3;
      B3: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end
  
  assign done = (current_state == B3);
  assign out_bytes = {byte1, byte2, byte3};
endmodule