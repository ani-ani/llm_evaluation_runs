module TopModule(
  input clk,
  input areset,
  input x,
  output reg z
);

  localparam STATE_A = 2'b01;
  localparam STATE_B = 2'b10;

  reg [1:0] state;

  always @(posedge clk or posedge areset) begin
    if (areset) begin
      state <= STATE_A;
    end else begin
      case (state)
        STATE_A: begin
          if (x == 0) begin
            state <= STATE_A;
          end else begin
            state <= STATE_B;
          end
        end
        STATE_B: begin
          state <= STATE_B;
        end
        default: state <= STATE_A;
      endcase
    end
  end

  always @(*) begin
    case (state)
      STATE_A: z = x;
      STATE_B: z = ~x;
      default: z = 0;
    endcase
  end

endmodule