module TopModule(
  input  clk,
  input  reset,
  input  x,
  output z
);

  reg [2:0] state, next_state;

  // State encoding
  localparam S000 = 3'b000;
  localparam S001 = 3'b001;
  localparam S010 = 3'b010;
  localparam S011 = 3'b011;
  localparam S100 = 3'b100;

  // Sequential logic: state register
  always @(posedge clk) begin
    if (reset)
      state <= S000;
    else
      state <= next_state;
  end

  // Combinational logic: next state logic
  always @(*) begin
    case (state)
      S000: next_state = x ? S001 : S000;
      S001: next_state = x ? S100 : S001;
      S010: next_state = x ? S001 : S010;
      S011: next_state = x ? S010 : S001;
      S100: next_state = x ? S100 : S011;
      default: next_state = S000;
    endcase
  end

  // Output logic
  assign z = (state == S011) || (state == S100);

endmodule