module garland_complexity (
  input clk,
  input rst_n,
  input start,
  input [4:0] n,
  input [15:0][4:0] p,
  output reg [5:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    PREPARE,
    DP_FILL,
    FINALIZE,
    DONE
  } state_t;

  state_t state;
  reg [5:0] min_complexity;
  reg [3:0] total_odds, total_evens;
  reg [3:0] fixed_odds, fixed_evens;
  reg [3:0] missing_count;
  reg [3:0] current_pos;
  reg [3:0] used_odds;
  reg current_parity;
  reg [5:0] dp_table [0:16][0:8][0:1];
  reg [3:0] i, j, k;

  // Initialize DP table
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      current_pos <= 0;
      used_odds <= 0;
      current_parity <= 0;
      min_complexity <= 0;
      total_odds <= 0;
      total_evens <= 0;
      fixed_odds <= 0;
      fixed_evens <= 0;
      missing_count <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PREPARE;
            done <= 0;
          end
        end
        PREPARE: begin
          // Count total odds and evens in 1..N
          total_odds <= (n + 1) / 2;
          total_evens <= n / 2;
          
          // Count fixed odds/evens and missing
          fixed_odds <= 0;
          fixed_evens <= 0;
          missing_count <= 0;
          for (i = 0; i < 16; i = i + 1) begin
            if (p[i] == 0) begin
              missing_count <= missing_count + 1;
            end else if (p[i] % 2 == 1) begin
              fixed_odds <= fixed_odds + 1;
            end else begin
              fixed_evens <= fixed_evens + 1;
            end
          end
          
          // Initialize DP table
          for (i = 0; i <= 16; i = i + 1) begin
            for (j = 0; j <= 8; j = j + 1) begin
              for (k = 0; k <= 1; k = k + 1) begin
                dp_table[i][j][k] <= 16'h3FF;
              end
            end
          end
          
          // Base case: position 0
          dp_table[0][0][0] <= 0;
          dp_table[0][0][1] <= 0;
          
          state <= DP_FILL;
          current_pos <= 0;
          used_odds <= 0;
          current_parity <= 0;
        end
        DP_FILL: begin
          if (current_pos < n) begin
            // Process current position
            if (p[current_pos] != 0) begin
              // Fixed bulb
              current_parity <= p[current_pos] % 2;
              if (current_pos > 0) begin
                // Calculate transitions
                for (j = 0; j <= 8; j = j + 1) begin
                  for (k = 0; k <= 1; k = k + 1) begin
                    if (dp_table[current_pos][j][k] != 16'h3FF) begin
                      if (k != current_parity) begin
                        if (dp_table[current_pos + 1][j][current_parity] > dp_table[current_pos][j][k] + 1) begin
                          dp_table[current_pos + 1][j][current_parity] <= dp_table[current_pos][j][k] + 1;
                        end
                      end else begin
                        if (dp_table[current_pos + 1][j][current_parity] > dp_table[current_pos][j][k]) begin
                          dp_table[current_pos + 1][j][current_parity] <= dp_table[current_pos][j][k];
                        end
                      end
                    end
                  end
                end
              end else begin
                // First position
                dp_table[1][0][current_parity] <= 0;
              end
            end else begin
              // Missing bulb - try both possibilities
              if (used_odds < total_odds) begin
                // Try odd
                current_parity <= 1;
                if (current_pos > 0) begin
                  for (j = 0; j <= 8; j = j + 1) begin
                    for (k = 0; k <= 1; k = k + 1) begin
                      if (dp_table[current_pos][j][k] != 16'h3FF) begin
                        if (k != 1) begin
                          if (dp_table[current_pos + 1][j + 1][1] > dp_table[current_pos][j][k] + 1) begin
                            dp_table[current_pos + 1][j + 1][1] <= dp_table[current_pos][j][k] + 1;
                          end
                        end else begin
                          if (dp_table[current_pos + 1][j + 1][1] > dp_table[current_pos][j][k]) begin
                            dp_table[current_pos + 1][j + 1][1] <= dp_table[current_pos][j][k];
                          end
                        end
                      end
                    end
                  end
                end else begin
                  dp_table[1][1][1] <= 0;
                end
              end
              
              if (used_odds + (total_evens - (current_pos - used_odds)) >= (n - current_pos)) begin
                // Try even
                current_parity <= 0;
                if (current_pos > 0) begin
                  for (j = 0; j <= 8; j = j + 1) begin
                    for (k = 0; k <= 1; k = k + 1) begin
                      if (dp_table[current_pos][j][k] != 16'h3FF) begin
                        if (k != 0) begin
                          if (dp_table[current_pos + 1][j][0] > dp_table[current_pos][j][k] + 1) begin
                            dp_table[current_pos + 1][j][0] <= dp_table[current_pos][j][k] + 1;
                          end
                        end else begin
                          if (dp_table[current_pos + 1][j][0] > dp_table[current_pos][j][k]) begin
                            dp_table[current_pos + 1][j][0] <= dp_table[current_pos][j][k];
                          end
                        end
                      end
                    end
                  end
                end else begin
                  dp_table[1][0][0] <= 0;
                end
              end
            end
            
            current_pos <= current_pos + 1;
          end else begin
            state <= FINALIZE;
          end
        end
        FINALIZE: begin
          // Find minimum complexity
          min_complexity <= 16'h3FF;
          for (j = 0; j <= 8; j = j + 1) begin
            for (k = 0; k <= 1; k = k + 1) begin
              if (dp_table[n][j][k] < min_complexity) begin
                min_complexity <= dp_table[n][j][k];
              end
            end
          end
          result <= min_complexity;
          state <= DONE;
        end
        DONE: begin
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule