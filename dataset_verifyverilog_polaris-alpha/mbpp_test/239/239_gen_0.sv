module sequence_counter (
  input        clk,
  input        rst_n,
  input        start,
  input  [15:0] m,
  input  [3:0]  n,
  output reg [15:0] result,
  output reg        done
);

  // State encoding
  localparam [1:0]
    S_IDLE    = 2'b00,
    S_INIT    = 2'b01,
    S_PROCESS = 2'b10,
    S_DONE    = 2'b11;

  reg [1:0] state, next_state;

  // 2D DP array: T[i][j], i=1..16, j=1..15
  // Using 0-based indices in SV: T[i][j] corresponds to T[i][j]
  reg [15:0] T [1:16][1:15];

  // Loop indices and temporaries
  reg [4:0]  i;        // supports up to 16
  reg [4:0]  j;        // supports up to 15
  reg [15:0] m_reg;
  reg [3:0]  n_reg;
  reg [15:0] sum_val;
  reg [4:0]  idx_i_half;  // floor(i/2)

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state  <= S_IDLE;
      result <= 16'd0;
      done   <= 1'b0;
      m_reg  <= 16'd0;
      n_reg  <= 4'd0;
      i      <= 5'd0;
      j      <= 5'd0;
    end else begin
      state <= next_state;
    end
  end

  // Next-state logic and control
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) begin
          next_state = S_INIT;
        end
      end
      S_INIT: begin
        // After clearing all entries, move to PROCESS
        // Transition controlled in sequential block once init completes
        // Here, keep S_INIT by default; will be overridden when init done
        next_state = S_INIT;
      end
      S_PROCESS: begin
        // Stay in PROCESS until all i,j processed
        next_state = S_PROCESS;
      end
      S_DONE: begin
        // Stay in DONE until next start (handled in seq block)
        next_state = S_DONE;
      end
      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  // Main sequential logic for operations and refined state transitions
  // Uses single-cycle updates for INIT and PROCESS loops
  integer ii, jj;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Already initialized in state flop; ensure DP cleared
      for (ii = 1; ii <= 16; ii = ii + 1) begin
        for (jj = 1; jj <= 15; jj = jj + 1) begin
          T[ii][jj] <= 16'd0;
        end
      end
      result <= 16'd0;
      done   <= 1'b0;
      state  <= S_IDLE;
      m_reg  <= 16'd0;
      n_reg  <= 4'd0;
      i      <= 5'd0;
      j      <= 5'd0;
    end else begin
      case (state)
        S_IDLE: begin
          done   <= 1'b0;
          result <= 16'd0;
          if (start) begin
            // Latch inputs
            m_reg <= (m > 16'd16) ? 16'd16 : m;  // Limit to array size
            n_reg <= (n > 4'd15)  ? 4'd15  : n;  // Limit to array size

            // Initialize indices for INIT
            i <= 5'd1;
            j <= 5'd1;

            // Clear array (first row/col this cycle via loops below)
            for (ii = 1; ii <= 16; ii = ii + 1) begin
              for (jj = 1; jj <= 15; jj = jj + 1) begin
                T[ii][jj] <= 16'd0;
              end
            end

            // Move to INIT
            state <= S_INIT;
          end
        end

        S_INIT: begin
          // All T pre-cleared in previous cycle; just set up for PROCESS
          // Start PROCESS from i=1, j=1
          i <= 5'd1;
          j <= 5'd1;
          state <= S_PROCESS;
        end

        S_PROCESS: begin
          done <= 1'b0;

          // If requested n_reg or m_reg are zero after limiting, handle trivial
          if (m_reg == 16'd0 || n_reg == 4'd0) begin
            result <= 16'd0;
            state  <= S_DONE;
          end else begin
            // Only compute within 1..m_reg,1..n_reg
            if (i <= m_reg && j <= n_reg) begin
              // Compute T[i][j] according to recurrence
              if (i < j || j == 0) begin
                T[i][j] <= 16'd0;
              end else if (j == 1) begin
                T[i][j] <= i[15:0];
              end else begin
                idx_i_half = i >> 1;  // floor(i/2)
                if (idx_i_half < 1)
                  idx_i_half = 1;    // safe-guard, though i>=2 when j>=2
                sum_val = T[i-1][j] + T[idx_i_half][j-1];
                T[i][j] <= sum_val;
              end

              // Increment j, then i (nested loop style)
              if (j < n_reg) begin
                j <= j + 5'd1;
              end else begin
                j <= 5'd1;
                if (i < m_reg) begin
                  i <= i + 5'd1;
                end else begin
                  // Completed all iterations
                  // Next cycle go to DONE and read T[m_reg][n_reg]
                  state <= S_DONE;
                end
              end
            end else begin
              // Safety: if indices exceed bounds, go to DONE
              state <= S_DONE;
            end
          end
        end

        S_DONE: begin
          // Output final result and assert done
          if (m_reg != 16'd0 && n_reg != 4'd0) begin
            result <= T[m_reg[4:0]][n_reg[3:0]];
          end else begin
            result <= 16'd0;
          end
          done <= 1'b1;

          // Wait for start to be deasserted and asserted again for next run
          if (!start) begin
            // Ready for next computation
            state <= S_IDLE;
          end
        end

        default: begin
          state <= S_IDLE;
        end
      endcase
    end
  end

endmodule