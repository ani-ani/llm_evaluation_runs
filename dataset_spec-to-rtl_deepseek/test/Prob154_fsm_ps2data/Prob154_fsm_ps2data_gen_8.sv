module TopModule(input clk, input reset, input [7:0] in, output reg [23:0] out_bytes, output done);
  typedef enum logic [1:0] {IDLE, BYTE2, BYTE3, DONE} state_t;
  state_t current_state, next_state;
  reg [7:0] byte1_reg, byte2_reg, byte3_reg;

  always @(posedge clk) begin
    if (reset) begin
      current_state <= IDLE;
      byte1_reg <= 8'b0; 
      byte2_reg <= 8'b0;
      byte3_reg <= 8'b0; 
    end else begin
      current_state <= next_state;
      case (next_state) 
        BYTE2: byte1_reg <= in;
        BYTE3: byte2_reg <= in;
        DONE: byte3_reg <= in;
        default: ; 
      endcase
    end
  end

  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: next_state = (in[3]) ? BYTE2 : IDLE;
      BYTE2: next_state = BYTE3;
      BYTE3: next_state = DONE;
      DONE: next_state = IDLE;
    endcase
  end

  assign done = (current_state == DONE);
  assign out_bytes = {byte1_reg, byte2_reg, byte3_reg};
endmodule
