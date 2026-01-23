module chess_domino_max_sum(input clk, input rst_n, input start, input [2:0] row_index, input [31:0] board_value, input [3:0] K, output reg [31:0] max_sum, output reg done, output reg valid);

reg [31:0] board [8][3];
reg [2:0] state;
reg [7:0] load_addr;

localparam K_MAX = 15;
reg [31:0] current_dp [K_MAX+1][8];
reg [31:0] next_dp [K_MAX+1][8];

reg [3:0] K_value;
reg [2:0] N_value;
reg [2:0] row_counter;
reg compute_done;

always @(posedge clk) begin
  if (!rst_n) begin
    state <= 3'b000;
    load_addr <= 8'b0;
    for (int i=0; i<8; i++) begin
      for (int j=0; j<3; j++) board[i][j] <= 32'b0;
    end
    for (int k=0; k<=K_MAX; k++) begin
      for (int mask=0; mask<8; mask++) begin
        current_dp[k][mask] <= 32'h80000000;
        next_dp[k][mask] <= 32'h80000000;
      end
    end
    K_value <= 4'b0;
    N_value <= 3'b000;
    row_counter <= 3'b000;
    compute_done <= 1'b0;
    max_sum <= 32'h00000000;
    done <= 1'b0;
    valid <= 1'b0;
  end else begin
    if (state == 3'b000) begin
      if (start == 1'b1) state <= 3'b001;
    end else if (state == 3'b001) begin
      if (load_addr < 24) begin
        int row = load_addr >> 2;
        int col = load_addr & 3;
        if (row < 8 && col < 3) board[row][col] <= board_value;
        load_addr <= load_addr + 1;
      end else begin
        state <= 3'b010;
        K_value <= K;
        N_value <= N;
        current_dp[0][0] <= 32'h00000000;
        for (int k=1; k<=K_MAX; k++) begin
          for (int mask=0; mask<8; mask++) current_dp[k][mask] <= 32'h80000000;
        end
        for (int mask=1; mask<8; mask++) current_dp[0][mask] <= 32'h80000000;
      end
    end else if (state == 3'b010) begin
      if (!compute_done) begin
        if (row_counter < N_value) begin
          for (int k=0; k<=K_MAX; k++) begin
            for (int mask=0; mask<8; mask++) next_dp[k][mask] <= 32'h80000000;
            if (current_dp[k][mask] != 32'h80000000) begin
              int available = ~mask & 7;
              // Horizontal domino 0-1
              if ((available & 3) == 3) begin
                int add = board[row_counter][0] + board[row_counter][1];
                if (k + 1 <= K_value) begin
                  if (current_dp[k][mask] + add > next_dp[k+1][0]) begin
                    next_dp[k+1][0] <= current_dp[k][mask] + add;
                  end
                end
              end
              // Horizontal domino 1-2
              if ((available & 6) == 6) begin
                int add = board[row_counter][1] + board[row_counter][2];
                if (k + 1 <= K_value) begin
                  if (current_dp[k][mask] + add > next_dp[k+1][0]) begin
                    next_dp[k+1][0] <= current_dp[k][mask] + add;
                  end
                end
              end
              // Vertical domino column 0
              if (((available & 1) && (row_counter < (N_value - 1))) begin
                int add = board[row_counter][0] + board[row_counter+1][0];
                if (k + 1 <= K_value) begin
                  next_dp[k+1][1] <= max(next_dp[k+1][1], current_dp[k][mask] + add);
                end
              end
              // Vertical domino column 1
              if (((available & 2) && (row_counter < (N_value - 1))) begin
                int add = board[row_counter][1] + board[row_counter+1][1];
                if (k + 1 <= K_value) begin
                  next_dp[k+1][2] <= max(next_dp[k+1][2], current_dp[k][mask] + add);
                end
              end
              // Vertical domino column 2
              if (((available & 4) && (row_counter < (N_value - 1))) begin
                int add = board[row_counter][2] + board[row_counter+1][2];
                if (k + 1 <= K_value) begin
                  next_dp[k+1][4] <= max(next_dp[k+1][4], current_dp[k][mask] + add);
                end
              end
            end
          end
          current_dp <= next_dp;
          row_counter <= row_counter + 1;
        end else begin
          compute_done <= 1'b1;
          state <= 3'b011;
        end
      end
    end else if (state == 3'b011) begin
      max_sum <= 32'h80000000;
      for (int k=0; k<=K_MAX; k++) begin
        if (k == K_value) begin
          for (int mask=0; mask<8; mask++) begin
            if (current_dp[k][mask] > max_sum) max_sum <= current_dp[k][mask];
          end
        end
      end
      done <= 1'b1;
      valid <= 1'b1;
    end
  end
endmodule