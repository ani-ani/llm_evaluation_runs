module TopModule(
input clk,
input reset,
input data,
output start_shifting
);
  localparam [2:0] S0 = 3'd0, S1 = 3'd1, S2 = 3'd2, S3 = 3'd3, S4 = 3'd4;
  reg [2:0] state;
  always @(posedge clk) begin
    if (reset) begin
      state <= S0;
    end else begin
      case (state)
        S0: state <= data ? S1 : S0;
        S1: state <= data ? S2 : S0;
        S2: state <= data ? S2 : S3;
        S3: state <= data ? S4 : S0;
        S4: state <= S4;
      endcase
    end
  end
  assign start_shifting = (state == S4);
endmodule