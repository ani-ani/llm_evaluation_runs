module coin_game_solver (
  input clk,                // clock signal
  input rst_n,              // active-low reset
  input start,              // start computation
  input [3:0] d_init,       // Donald's initial coins (1-15)
  input [3:0] g_init,       // Gladstone's initial coins (1-15)
  input [2:0] n_rounds,     // total rounds (1-8)
  input [2:0] k_distracted, // distracted rounds (0-8)

  output reg [3:0] m_coins, // maximum coins Donald can have
  output reg done           // high when computation complete
);

  // State encoding
  localparam [1:0] RESET = 2'b00;
  localparam [1:0] IDLE  = 2'b01;
  localparam [1:0] PROC  = 2'b10;
  localparam [1:0] DONE  = 2'b11;

  reg [1:0] state, next_state;

  // Internal registers
  reg [3:0] d_reg;     // current Donald coins during simulation
  reg [3:0] g_reg;     // current Gladstone coins during simulation
  reg [2:0] rounds_left;
  reg [2:0] k_left;
  reg [3:0] saved_d_init;
  reg [3:0] saved_g_init;
  reg [2:0] saved_n_rounds;
  reg [2:0] saved_k_dist;
  reg [2:0] round_counter; // counts how many cycles spent in PROCESS (1..8)

  // Sequential state updates (active-low async reset)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= RESET;
    end else begin
      state <= next_state;
    end
  end

  // Internal register updates per state
  always @(posedge clk) begin
    case (state)
      RESET: begin
        d_reg         <= 4'b0;
        g_reg         <= 4'b0;
        rounds_left   <= 3'b0;
        k_left        <= 3'b0;
        saved_d_init  <= 4'b0;
        saved_g_init  <= 4'b0;
        saved_n_rounds<= 3'b0;
        saved_k_dist  <= 3'b0;
        round_counter <= 3'b0;
        m_coins       <= 4'b0;
        done          <= 1'b0;
      end

      IDLE: begin
        // Hold outputs low in IDLE
        m_coins <= 4'b0;
        done    <= 1'b0;
        // When start is asserted, load inputs and enter PROCESS next cycle
        if (start) begin
          saved_d_init  <= d_init;
          saved_g_init  <= g_init;
          saved_n_rounds<= n_rounds;
          saved_k_dist  <= k_distracted;
          d_reg         <= d_init;
          g_reg         <= g_init;
          rounds_left   <= n_rounds;
          k_left        <= k_distracted;
          round_counter <= 3'b0;
        end
      end

      PROC: begin
        // Each cycle performs one round update
        if (rounds_left > 3'b0) begin
          // Non-distracted round: Donald bets 1 coin and loses it
          if (k_left == 3'b0) begin
            d_reg <= d_reg - 4'd1;
            g_reg <= g_reg + 4'd1;
          end
          // Distracted round: Donald bets min(d_current, g_current) and wins them
          else begin
            if (d_reg < g_reg) begin
              d_reg <= d_reg + d_reg; // 2*d
              g_reg <= g_reg - d_reg; // g - d (before doubling)
            end else begin
              d_reg <= d_reg + g_reg; // d + g
              g_reg <= g_reg - g_reg; // 2*g (now zero)
            end
            k_left <= k_left - 3'd1;
          end
          rounds_left   <= rounds_left - 3'd1;
          round_counter <= round_counter + 3'd1;
        end
      end

      DONE: begin
        // Hold result and done high
        m_coins <= d_reg;
        done    <= 1'b1;
      end

      default: begin
        // Guard against uninitialized state
        d_reg         <= 4'b0;
        g_reg         <= 4'b0;
        rounds_left   <= 3'b0;
        k_left        <= 3'b0;
        saved_d_init  <= 4'b0;
        saved_g_init  <= 4'b0;
        saved_n_rounds<= 3'b0;
        saved_k_dist  <= 3'b0;
        round_counter <= 3'b0;
        m_coins       <= 4'b0;
        done          <= 1'b0;
      end
    endcase
  end

  // Next-state logic
  always @(*) begin
    case (state)
      RESET: next_state = IDLE;
      IDLE:  next_state = start ? PROC : IDLE;
      PROC:  next_state = (round_counter == saved_n_rounds) ? DONE : PROC;
      DONE:  next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

endmodule
