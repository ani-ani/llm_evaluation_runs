module TopModule(
  input clk,
  input areset,
  input x,
  output reg z
);

  localparam A = 2'b01;
  localparam B = 2'b10;

  reg [1:0] state;

  always_ff @(posedge clk or posedge areset) begin
    if (areset)
      state <= A;
    else begin
      case (state)
        A: state <= (x == 1'b0) ? A : B;
        B: state <= B;
        default: state <= A;
      endcase
    end
  end

  always_comb begin
    case (state)
      A: z = x ? 1'b1 : 1'b0;
      B: z = x ? 1'b0 : 1'b1;
      default: z = 1'b0;
    endcase
  end

endmodule