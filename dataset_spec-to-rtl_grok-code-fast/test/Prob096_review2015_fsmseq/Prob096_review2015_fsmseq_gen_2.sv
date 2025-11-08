module TopModule (
  input clk,
  input reset,
  input data,
  output start_shifting
);

  parameter S0 = 3'b000;
  parameter S1 = 3'b001;
  parameter S2 = 3'b010;
  parameter S3 = 3'b011;
  parameter S4 = 3'b100;

  reg [2:0] state;

  always_ff @(posedge clk) begin
    if (reset) begin
      state <= S0;
    end else begin
      case (state)
        S0: state <= data ? S1 : S0;
        S1: state <= data ? S2 : S0;
        S2: state <= data ? S2 : S3;
        S3: state <= data ? S4 : S0;
        S4: state <= S4;
        default: state <= S0;
      endcase
    end
  end

  assign start_shifting = (state == S4);

endmodule