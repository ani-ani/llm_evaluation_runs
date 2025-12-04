module linear_congruence_solver(
  input clk,
  input rst_n,
  input start,
  input [19:0] a,
  input [19:0] b,
  input [19:0] M,
  input [19:0] P,
  output reg [19:0] x,
  output reg done
);

typedef enum logic [2:0] { IDLE, INIT, EUCLID, CHECK_DIV, DONE } state_t;
reg [2:0] state, next_state;
reg [19:0] a_reg, b_reg, M_reg, P_reg;
reg [19:0] K_reg;
reg [19:0] r, new_r;
reg [19:0] d;
reg signed [20:0] t_reg, new_t_reg;
reg [19:0] a_reduced, M_reduced, K_reduced;
reg [19:0] x_temp;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 0;
    x <= 0;
    a_reg <= 0;
    b_reg <= 0;
    M_reg <= 0;
    P_reg <= 0;
    K_reg <= 0;
    r <= 0;
    new_r <= 0;
    t_reg <= 0;
    new_t_reg <= 0;
    d <= 0;
    a_reduced <= 0;
    M_reduced <= 0;
    K_reduced <= 0;
  end else begin
    state <= next_state;
    done <= 0;
    case (state)
      IDLE: begin
        if (start) begin
          a_reg <= a;
          b_reg <= b;
          M_reg <= M;
          P_reg <= P;
          if (b <= P) K_reg <= (P - b) % M;
          else K_reg <= (M - ((b - P) % M)) % M;
          next_state <= INIT;
        end
      end

      INIT: begin
        if (a_reg == 0) begin
          x <= (b_reg % M_reg == P_reg) ? 0 : 0;
          done <= 1;
          next_state <= DONE;
        end else begin
          r <= M_reg;
          new_r <= a_reg;
          t_reg <= 0;
          new_t_reg <= 1;
          next_state <= EUCLID;
        end
      end

      EUCLID: begin
        if (new_r == 0) begin
          d <= r;
          next_state <= CHECK_DIV;
        end else begin
          automatic logic [19:0] quotient = r / new_r;
          automatic logic [19:0] temp_r = r % new_r;
          automatic logic signed [20:0] temp_t = t_reg - (quotient * new_t_reg);
          r <= new_r;
          new_r <= temp_r;
          t_reg <= new_t_reg;
          new_t_reg <= temp_t;
        end
      end

      CHECK_DIV: begin
        automatic logic [19:0] remainder = K_reg % d;
        if (remainder != 0) begin
          x <= 0;
          done <= 1;
          next_state <= DONE;
        end else begin
          a_reduced <= a_reg / d;
          M_reduced <= M_reg / d;
          K_reduced <= K_reg / d;
          automatic logic [19:0] signed_t = t_reg[19:0];
          automatic logic signed [19:0] modinv = signed_t % M_reduced;
          if (modinv[19]) modinv = modinv + M_reduced;
          x_temp <= (K_reduced * modinv) % M_reduced;
          x <= x_temp;
          done <= 1;
          next_state <= DONE;
        end
      end

      DONE: begin
        next_state <= IDLE;
      end

      default: next_state <= IDLE;
    endcase
  end
end
endmodule