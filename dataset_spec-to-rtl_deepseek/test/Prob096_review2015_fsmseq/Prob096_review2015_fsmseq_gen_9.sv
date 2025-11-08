module TopModule(input clk, input reset, input data, output start_shifting);
  localparam S0 = 3'b000;
  localparam S1 = 3'b001;
  localparam S2 = 3'b010;
  localparam S3 = 3'b011;
  localparam S4 = 3'b100;
  
  reg [2:0] state, next_state;
  
  always_ff @(posedge clk) begin
    if (reset) state <= S0;
    else state <= next_state;
  end
  
  always_comb begin
    next_state = state;
    case (state)
      S0: next_state = data ? S1 : S0;
      S1: next_state = data ? S2 : S0;
      S2: next_state = data ? S2 : S3;
      S3: next_state = data ? S4 : S0;
      S4: next_state = S4;
      default: next_state = S0;
    endcase
  end
  
  assign start_shifting = (state == S4);
endmodule