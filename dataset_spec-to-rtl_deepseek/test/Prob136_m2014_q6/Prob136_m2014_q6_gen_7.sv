module TopModule(input clk, input reset, input w, output z);
  localparam [2:0] S_A = 3'b000,
                   S_B = 3'b001,
                   S_C = 3'b010,
                   S_D = 3'b011,
                   S_E = 3'b100,
                   S_F = 3'b101;

  reg [2:0] current_state;

  always @(posedge clk) begin
    if (reset)
      current_state <= S_A;
    else begin
      case (current_state)
        S_A: current_state <= w ? S_A : S_B;
        S_B: current_state <= w ? S_D : S_C;
        S_C: current_state <= w ? S_D : S_E;
        S_D: current_state <= w ? S_A : S_F;
        S_E: current_state <= w ? S_D : S_E;
        S_F: current_state <= w ? S_D : S_C;
        default: current_state <= S_A;
      endcase
    end
  end

  assign z = (current_state == S_E) || (current_state == S_F);
endmodule