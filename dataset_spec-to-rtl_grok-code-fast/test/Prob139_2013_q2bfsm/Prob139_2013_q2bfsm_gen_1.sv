module TopModule(
  input clk,
  input resetn,
  input x,
  input y,
  output reg f,
  output reg g
);

  parameter A = 4'd0;
  parameter B = 4'd1;
  parameter S0 = 4'd2;
  parameter S1 = 4'd3;
  parameter S2 = 4'd4;
  parameter S3 = 4'd5;
  parameter G1 = 4'd6;
  parameter G2 = 4'd7;
  parameter P1 = 4'd8;
  parameter P0 = 4'd9;

  reg [3:0] state, next_state;

  always @(posedge clk) begin
    if (!resetn) begin
      state <= A;
    end else begin
      state <= next_state;
    end
  end

  always @(*) begin
    if (!resetn) begin
      next_state = A;
      f = 1'b0;
      g = 1'b0;
    end else begin
      case (state)
        A: begin
          next_state = B;
          f = 1'b0;
          g = 1'b0;
        end
        B: begin
          next_state = S0;
          f = 1'b1;
          g = 1'b0;
        end
        S0: begin
          next_state = (x == 1'b1) ? S1 : S0;
          f = 1'b0;
          g = 1'b0;
        end
        S1: begin
          next_state = (x == 1'b0) ? S2 : S0;
          f = 1'b0;
          g = 1'b0;
        end
        S2: begin
          next_state = (x == 1'b1) ? S3 : S0;
          f = 1'b0;
          g = 1'b0;
        end
        S3: begin
          next_state = G1;
          f = 1'b0;
          g = 1'b0;
        end
        G1: begin
          next_state = (y == 1'b1) ? P1 : G2;
          f = 1'b0;
          g = 1'b1;
        end
        G2: begin
          next_state = (y == 1'b1) ? P1 : P0;
          f = 1'b0;
          g = 1'b1;
        end
        P1: begin
          next_state = P1;
          f = 1'b0;
          g = 1'b1;
        end
        P0: begin
          next_state = P0;
          f = 1'b0;
          g = 1'b0;
        end
        default: begin
          next_state = A;
          f = 1'b0;
          g = 1'b0;
        end
      endcase
    end
  end

endmodule