module TopModule(
  input clk,
  input areset,
  input x,
  output reg z
);

  reg [1:0] state;

  always @(posedge clk or posedge areset) begin
    if (areset) begin
      state <= 2'b01; // State A
      z <= 1'b0;
    end else begin
      case (state)
        2'b01: begin // State A
          if (x == 0) begin
            z <= 0;
            state <= 2'b01;
          end else begin
            z <= 1;
            state <= 2'b10; // To State B
          end
        end
        2'b10: begin // State B
          if (x == 0) begin
            z <= 1;
            state <= 2'b10;
          end else begin
            z <= 0;
            state <= 2'b10;
          end
        end
        default: begin
          state <= 2'b01;
          z <= 1'b0;
        end
      endcase
    end
  end
endmodule