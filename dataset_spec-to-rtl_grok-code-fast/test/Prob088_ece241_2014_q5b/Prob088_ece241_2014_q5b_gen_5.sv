module TopModule(
  input clk,
  input areset,
  input x,
  output logic z
);

  localparam [1:0] A = 2'b10;
  localparam [1:0] B = 2'b01;

  logic [1:0] state_ff;

  always_ff @(posedge clk or posedge areset) begin
    if (areset)
      state_ff <= A;
    else begin
      case (state_ff)
        A: state_ff <= x ? B : A;
        B: state_ff <= B;
        default: state_ff <= A;
      endcase
    end
  end

  always_comb begin
    case (state_ff)
      A: z = x;
      B: z = ~x;
      default: z = 1'b0;
    endcase
  end

endmodule