module TopModule(input clk, input reset, input [7:0] in, output reg [23:0] out_bytes, output done);
  typedef enum {S_IDLE, S_BYTE2, S_BYTE3} state_t;
  reg [7:0] byte1, byte2, byte3;
  state_t current_state, next_state;
  reg done_reg;

  always_ff @(posedge clk) begin
    if (reset) begin
      current_state <= S_IDLE;
      done_reg <= 1'b0;
    end else begin
      current_state <= next_state;
      done_reg <= (current_state == S_BYTE3);
    end
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      byte1 <= 8'h0;
      byte2 <= 8'h0;
      byte3 <= 8'h0;
    end else begin
      case (current_state)
        S_IDLE: byte1 <= in;
        S_BYTE2: byte2 <= in;
        S_BYTE3: byte3 <= in;
      endcase
    end
  end

  assign done = done_reg;
  assign out_bytes = {byte1, byte2, byte3};

  always_comb begin
    next_state = current_state;
    case (current_state)
      S_IDLE: next_state = (in[3]) ? S_BYTE2 : S_IDLE; 
      S_BYTE2: next_state = S_BYTE3;
      S_BYTE3: next_state = S_IDLE;
    endcase
  end
endmodule