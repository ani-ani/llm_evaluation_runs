module TopModule (
  input clk,
  input reset,
  input in,
  output disc,
  output flag,
  output err
);

  // State definitions
  localparam S0 = 4'b0000;
  localparam S1 = 4'b0001;
  localparam S2 = 4'b0010;
  localparam S3 = 4'b0011;
  localparam S4 = 4'b0100;
  localparam S5 = 4'b0101;
  localparam SD = 4'b0110;
  localparam S6 = 4'b0111;
  localparam SF = 4'b1000;
  localparam SE = 4'b1001;

  reg [3:0] state;

  // State transition on posedge clk
  always @(posedge clk) begin
    if (reset)
      state <= S0;
    else begin
      case (state)
        S0: state <= in ? S1 : S0;
        S1: state <= in ? S2 : S0;
        S2: state <= in ? S3 : S0;
        S3: state <= in ? S4 : S0;
        S4: state <= in ? S5 : S0;
        S5: state <= in ? S6 : SD;
        S6: state <= in ? SE : SF;
        SD: state <= in ? S1 : S0;
        SF: state <= in ? S1 : S0;
        SE: state <= in ? SE : S0;
        default: state <= S0;
      endcase
    end
  end

  // Moore outputs
  assign disc = (state == SD);
  assign flag = (state == SF);
  assign err = (state == SE);

endmodule