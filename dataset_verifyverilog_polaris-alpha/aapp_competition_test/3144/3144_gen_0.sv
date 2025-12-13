module coin_game_solver(
  input        clk,
  input        rst_n,
  input        start,
  input  [3:0] d_init,
  input  [3:0] g_init,
  input  [2:0] n_rounds,
  input  [2:0] k_distracted,
  output reg [3:0] m_coins,
  output reg       done
);

  // State encoding
  localparam [1:0]
    S_RESET   = 2'd0,
    S_IDLE    = 2'd1,
    S_PROCESS = 2'd2,
    S_DONE    = 2'd3;

  reg [1:0] state, next_state;

  // Internal registers
  reg [3:0] d_cur;              // Donald current coins
  reg [3:0] g_cur;              // Gladstone current coins
  reg [2:0] rounds_left;        // remaining rounds to process
  reg [2:0] distracted_left;    // remaining distracted rounds
  reg [3:0] bet;                // bet amount for current round

  // Next-state and output control signals
  reg [3:0] d_next;
  reg [3:0] g_next;
  reg [2:0] rounds_left_next;
  reg [2:0] distracted_left_next;
  reg [3:0] m_coins_next;
  reg       done_next;
  reg [1:0] state_next;

  // Combinational next-state / datapath logic
  always @* begin
    // Default hold values
    state_next           = state;
    d_next               = d_cur;
    g_next               = g_cur;
    rounds_left_next     = rounds_left;
    distracted_left_next = distracted_left;
    m_coins_next         = m_coins;
    done_next            = 1'b0;
    bet                  = 4'd0;

    case (state)
      S_RESET: begin
        // After reset deassertion, go to IDLE
        state_next           = S_IDLE;
        d_next               = 4'd0;
        g_next               = 4'd0;
        rounds_left_next     = 3'd0;
        distracted_left_next = 3'd0;
        m_coins_next         = 4'd0;
        done_next            = 1'b0;
      end

      S_IDLE: begin
        done_next = 1'b0;
        if (start) begin
          // Latch inputs and prepare for processing
          d_next               = d_init;
          g_next               = g_init;
          rounds_left_next     = n_rounds;
          distracted_left_next = k_distracted;
          m_coins_next         = d_init;
          state_next           = S_PROCESS;
        end
      end

      S_PROCESS: begin
        done_next = 1'b0;
        if (rounds_left == 3'd0) begin
          // All rounds processed, go to DONE
          m_coins_next = d_cur;
          state_next   = S_DONE;
        end else begin
          // Process one round
          if (distracted_left != 3'd0) begin
            // Distracted round: Donald bets min(d_cur, g_cur) and wins it
            if (d_cur <= g_cur)
              bet = d_cur;
            else
              bet = g_cur;
            // Donald gains bet, Gladstone loses bet
            d_next               = d_cur + bet;
            g_next               = g_cur - bet;
            distracted_left_next = distracted_left - 3'd1;
          end else begin
            // Non-distracted round: Donald bets 1 coin and loses it
            if (d_cur != 4'd0)
              d_next = d_cur - 4'd1;
            else
              d_next = 4'd0;
            // Gladstone unaffected on losing round
            g_next = g_cur;
          end

          // Decrement rounds counter
          rounds_left_next = rounds_left - 3'd1;
        end
      end

      S_DONE: begin
        // Signal completion; stay here until start is deasserted,
        // then wait for next start in IDLE
        done_next = 1'b1;
        if (!start) begin
          state_next = S_IDLE;
        end
      end

      default: begin
        state_next = S_RESET;
      end
    endcase
  end

  // Sequential state and register updates
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= S_RESET;
      d_cur           <= 4'd0;
      g_cur           <= 4'd0;
      rounds_left     <= 3'd0;
      distracted_left <= 3'd0;
      m_coins         <= 4'd0;
      done            <= 1'b0;
    end else begin
      state           <= state_next;
      d_cur           <= d_next;
      g_cur           <= g_next;
      rounds_left     <= rounds_left_next;
      distracted_left <= distracted_left_next;
      m_coins         <= m_coins_next;
      done            <= done_next;
    end
  end

endmodule