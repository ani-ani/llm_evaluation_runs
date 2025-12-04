module graph_path_counter(
  input clk,
  input rst_n,
  input start,
  input [1:0] N,
  input [2:0] M,
  input [31:0] edges,
  output reg done,
  output reg [31:0] result
);

  typedef enum { IDLE, INIT, BUILD_ADJ, CYCLE_DETECT, COUNT_PATHS, DONE } state_t;
  state_t state, next_state;

  reg [1:0] N_reg;
  reg [2:0] M_reg;
  reg [2:0] adj_mat [0:3][0:3];
  reg [3:0][3:0] reach;
  reg [1:0] k;
  reg has_cycle;
  reg [29:0] dp [0:3];
  reg [1:0] step;
  reg [0:3][0:3] adj_temp;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      N_reg <= 0;
      M_reg <= 0;
      for (int i=0; i<4; i++) begin
        for (int j=0; j<4; j++) adj_mat[i][j] <= 0;
        dp[i] <= 0;
      end
      reach <= '0;
      k <= 0;
      has_cycle <= 0;
      step <= 0;
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          done <= 0;
          has_cycle <= 0;
          step <= 0;
          k <= 0;
          if (start) next_state <= INIT;
          else next_state <= IDLE;
        end
        
        INIT: begin
          N_reg <= N;
          M_reg <= M;
          for (int i=0; i<4; i++) begin
            for (int j=0; j<4; j++) begin
              adj_mat[i][j] <= 0;
              reach[i][j] <= 0;
            end
          end
          next_state <= BUILD_ADJ;
        end
        
        BUILD_ADJ: begin
          for (int i=0; i<4; i++) begin
            for (int j=0; j<4; j++) begin
              adj_mat[i][j] <= adj_temp[i][j];
            end
          end
          for (int i=0; i<4; i++) begin
            for (int j=0; j<4; j++) begin
              if (i == j) reach[i][j] <= adj_mat[i][j] > 0;
              else reach[i][j] <= adj_mat[i][j] > 0;
            end
          end
          k <= 0;
          next_state <= CYCLE_DETECT;
        end
        
        CYCLE_DETECT: begin
          if (k < 4) begin
            for (int i=0; i<4; i++) begin
              for (int j=0; j<4; j++) begin
                reach[i][j] <= reach[i][j] || (reach[i][k] && reach[k][j]);
              end
            end
            k <= k + 1;
          end else begin
            has_cycle <= 0;
            for (int u=0; u<4; u++) begin
              if (u > N_reg) continue;
              if (reach[0][u] && ( (u == 1 || reach[u][1]) && reach[u][u]) ) has_cycle <= 1;
            end
            if (has_cycle) next_state <= DONE;
            else next_state <= COUNT_PATHS;
          end
        end
        
        COUNT_PATHS: begin
          if (step == 0) begin
            dp[0] <= 1;
            for (int i=1; i<4; i++) dp[i] <= 0;
            step <= step + 1;
          end else begin
            if (step <= N_reg+1) begin
              automatic logic [29:0] next_dp [0:3];
              for (int j=0; j<4; j++) begin
                next_dp[j] = 0;
                if (j > N_reg) continue;
                for (int i=0; i<4; i++) begin
                  if (i > N_reg) continue;
                  next_dp[j] = next_dp[j] + (dp[i] * adj_mat[i][j]);
                end
              end
              for (int j=0; j<4; j++) dp[j] <= next_dp[j] % 30'd1000000000;
              step <= step + 1;
            end else begin
              next_state <= DONE;
            end
          end
        end
        
        DONE: begin
          done <= 1;
          result[31] <= has_cycle;
          result[30:0] <= (has_cycle || N_reg < 1) ? 0 : dp[1][29:0];
          next_state <= IDLE;
        end
      endcase
    end
  end

  always_comb begin
    for (int i=0; i<4; i++) begin
      for (int j=0; j<4; j++) begin
        adj_temp[i][j] = 0;
      end
    end
    for (int e=0; e<8; e++) begin
      if (e < M) begin
        automatic logic [3:0] edge_data = edges >> (4 * e);
        automatic logic [1:0] A = edge_data[3:2];
        automatic logic [1:0] B = edge_data[1:0];
        if (A <= N && B <= N) adj_temp[A][B] = adj_temp[A][B] + 1;
      end
    end
    next_state = state;
  end

endmodule
