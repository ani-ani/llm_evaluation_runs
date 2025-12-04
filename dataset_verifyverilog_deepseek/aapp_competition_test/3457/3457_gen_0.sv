module path_counter(
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  input [3:0] X,
  input [3:0] Y,
  output reg [31:0] result,
  output reg done
);
  typedef enum { IDLE, INIT, PROCESS, COMPLETE } state_t;
  state_t state;
  reg [3:0] i_reg, j_reg;
  reg [31:0] dp_mem [0:8][0:8];
  reg [31:0] sum;

  always_comb begin
    sum = 0;
    if (i_reg >= X && j_reg >= Y) begin
      for (int a = 0; a <= (i_reg - X); a++) begin
        for (int b = 0; b <= (j_reg - Y); b++) begin
          sum = (sum + dp_mem[a][b]) % 32'd1000000007;
        end
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i <= 8; i++) begin
        for (int j = 0; j <= 8; j++) begin
          dp_mem[i][j] <= '0;
        end
      end
      state <= IDLE;
      i_reg <= '0;
      j_reg <= '0;
      done <= '0;
      result <= '0;
    end else begin
      case (state)
        IDLE: begin
          done <= '0;
          if (start) begin
            state <= INIT;
          end
        end
        INIT: begin
          dp_mem[0][0] <= 32'd1;
          i_reg <= '0;
          j_reg <= '0;
          state <= PROCESS;
        end
        PROCESS: begin
          if (i_reg != '0 || j_reg != '0) begin
            dp_mem[i_reg][j_reg] <= sum;
          end
          if (i_reg == N && j_reg == N) begin
            state <= COMPLETE;
          end else begin
            if (j_reg == N) begin
              j_reg <= '0;
              i_reg <= i_reg + 1;
            end else begin
              j_reg <= j_reg + 1;
            end
          end
        end
        COMPLETE: begin
          done <= 1'b1;
          result <= dp_mem[N][N];
          if (!start) begin
            state <= IDLE;
            done <= '0;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end
endmodule