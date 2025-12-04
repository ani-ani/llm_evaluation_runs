module coin_game_solver (
  input clk,
  input rst_n,
  input start,
  input [3:0] d_init,
  input [3:0] g_init,
  input [2:0] n_rounds,
  input [2:0] k_distracted,
  output reg [3:0] m_coins,
  output reg done
);

  // FSM states
  typedef enum {
    RESET,
    IDLE,
    PROCESS,
    DONE
  } state_t;
  
  reg [1:0] state;
  reg [3:0] d_current, g_current;
  reg [2:0] round_count;
  reg [2:0] k_remaining;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= RESET;
      done <= 1'b0;
      m_coins <= 4'b0;
    end else begin
      case (state)
        RESET: begin
          done <= 1'b0;
          m_coins <= 4'b0;
          state <= IDLE;
        end
        
        IDLE: begin
          if (start) begin
            d_current <= d_init;
            g_current <= g_init;
            round_count <= n_rounds;
            k_remaining <= k_distracted;
            state <= PROCESS;
          end
        end
        
        PROCESS: begin
          if (round_count > 0) begin
            if (k_remaining > 0) begin
              // Distracted round
              d_current <= d_current + ((d_current < g_current) ? d_current : g_current);
              g_current <= g_current - ((d_current < g_current) ? d_current : g_current);
              k_remaining <= k_remaining - 1;
            end else begin
              // Non-distracted round
              d_current <= d_current - 1'b1;
            end
            round_count <= round_count - 1;
          end else begin
            state <= DONE;
          end
        end
        
        DONE: begin
          m_coins <= d_current;
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule