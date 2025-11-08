module TopModule(input clk, reset, in, output out);
  localparam [1:0] A_STATE = 2'b00,
                   B_STATE = 2'b01,
                   C_STATE = 2'b10,
                   D_STATE = 2'b11;
  reg [1:0] current_state, next_state;

  always_ff @(posedge clk) begin
    if (reset)
      current_state <= A_STATE;
    else
      current_state <= next_state;
  end

  always_comb begin
    case (current_state)
      A_STATE: next_state = in ? B_STATE : A_STATE;
      B_STATE: next_state = in ? B_STATE : C_STATE;
      C_STATE: next_state = in ? D_STATE : A_STATE;
      D_STATE: next_state = in ? B_STATE : C_STATE;
      default: next_state = A_STATE;
    endcase
  end

  assign out = (current_state == D_STATE) ? 1'b1 : 1'b0;
endmodule