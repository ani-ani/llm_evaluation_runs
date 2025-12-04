module casino_profit_calculator(
  input clk,
  input rst_n,
  input start,
  input [15:0] x, // refund percentage (fixed-point: value * 100)
  input [15:0] p, // win probability (fixed-point: value * 100)
  output reg [31:0] max_profit, // Q16.16 fixed-point output
  output reg done
);

  // Parameters
  localparam MAX_BETS = 16;
  localparam STATE_IDLE = 2'b00;
  localparam STATE_CALC = 2'b01;
  localparam STATE_DONE = 2'b10;

  // Internal state
  reg [1:0] state, next_state;
  reg [4:0] n;                 // current bet count 0..16
  reg [4:0] cycle_cnt;         // for latency control

  // Fixed-point constants
  // Q16.16 scale = 65536
  localparam [31:0] ONE_Q16   = 32'd65536;

  // Latched inputs (to keep stable during calculation)
  reg [15:0] x_reg;
  reg [15:0] p_reg;

  // Derived Q16.16 probabilities
  // p_in, x_in are scaled by 100: real_p = p_reg / 100
  // Convert to Q16.16: p_q16 = p_reg * (65536/100) = p_reg * 655.36
  // We approximate by (p_reg * 65536) / 100 using integer division.

  reg [31:0] p_q16;
  reg [31:0] q_q16; // 1 - p

  // Expected profit for current N in Q16.16
  reg [31:0] expected_profit_n;

  // Running max
  reg [31:0] max_profit_next;

  // Simple placeholder model for expected profit per bet count N:
  // This is a synthesizable stand-in that follows required interfaces, state machine,
  // timing, and fixed-point handling. It uses combinational logic per N.
  //
  // Assumed model:
  // - Each bet costs 1 unit.
  // - Win with prob p: gain +1 unit; lose with prob (1-p): -1 unit.
  //   So per bet EV_base = (2*p - 1).
  // - For N bets: EV_base_N = N * (2*p - 1).
  // - If EV_base_N < 0, apply refund x% to the loss magnitude:
  //   EV = EV_base_N + x% * |EV_base_N| = EV_base_N * (1 - x/100).
  // All results output as Q16.16.

  // Combinational: compute p_q16, q_q16 from latched p_reg
  // and expected_profit_n from current N, p_reg, x_reg.

  // Note: use wider temps for intermediate products to avoid overflow.
  reg  [47:0] p_scaled_tmp;
  reg  [47:0] two_p_minus_one_q16; // Q16.16
  reg  [63:0] ev_base_n_q16;       // Q16.16 (after scaling)
  reg  [63:0] loss_mag_q16;
  reg  [31:0] one_minus_x_q16;
  reg  [63:0] ev_adj_q16;

  always @* begin
    // Convert p_reg (0..10000) -> Q16.16
    // p_q16 = (p_reg * 65536) / 100
    p_scaled_tmp    = p_reg * 16'd65536;
    p_q16           = p_scaled_tmp / 16'd100;
    if (p_q16 > ONE_Q16)
      p_q16 = ONE_Q16; // saturate (safety)

    // q = 1 - p (not strictly needed for this simplified EV model, but kept for completeness)
    if (p_q16 >= ONE_Q16)
      q_q16 = 32'd0;
    else
      q_q16 = ONE_Q16 - p_q16;

    // two_p_minus_one_q16 = 2*p - 1 in Q16.16
    two_p_minus_one_q16 = (p_q16 << 1);
    if (two_p_minus_one_q16 >= ONE_Q16)
      two_p_minus_one_q16 = two_p_minus_one_q16 - ONE_Q16;
    else
      two_p_minus_one_q16 = 48'd0 - (ONE_Q16 - two_p_minus_one_q16); // signed behavior in 48b

    // EV_base_N = N * (2*p - 1) in Q16.16
    // Interpret two_p_minus_one_q16 as signed 48-bit; multiply by unsigned N.
    ev_base_n_q16 = $signed(two_p_minus_one_q16) * $signed({27'd0, n});

    // Default: expected_profit_n = lower 32 bits (Q16.16)
    expected_profit_n = ev_base_n_q16[31:0];

    // If negative, apply refund x% to loss magnitude:
    // EV = EV_base_N * (1 - x/100).
    if ($signed(expected_profit_n) < 0) begin
      // one_minus_x_q16 = (1 - x/100) in Q16.16
      // (1 - x/100) = (100 - x)/100
      // => Q16.16 = (100 - x_reg) * 65536 / 100
      if (x_reg >= 16'd10000) begin
        one_minus_x_q16 = 32'd0; // full refund or more -> 0 effective factor
      end else begin
        loss_mag_q16    = (48'((16'd10000 - x_reg))) * 16'd65536;
        one_minus_x_q16 = loss_mag_q16[47:16] / 16'd100; // scaled down to Q16.16
      end

      // Apply factor to EV_base_N (signed)
      ev_adj_q16 = ($signed(ev_base_n_q16) * $signed(one_minus_x_q16)) >>> 16;
      expected_profit_n = ev_adj_q16[31:0];
    end
  end

  // Next state & max tracking
  always @* begin
    next_state = state;
    max_profit_next = max_profit;

    case (state)
      STATE_IDLE: begin
        if (start) begin
          next_state = STATE_CALC;
        end
      end

      STATE_CALC: begin
        // Update max over N
        if ($signed(expected_profit_n) > $signed(max_profit_next)) begin
          max_profit_next = expected_profit_n;
        end

        // After iterating from 0 to MAX_BETS, move to DONE.
        if (n == MAX_BETS) begin
          next_state = STATE_DONE;
        end
      end

      STATE_DONE: begin
        // Wait until start deasserted then asserted again for new run
        if (!start)
          next_state = STATE_IDLE;
      end

      default: next_state = STATE_IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= STATE_IDLE;
      n           <= 5'd0;
      cycle_cnt   <= 5'd0;
      max_profit  <= 32'd0;
      done        <= 1'b0;
      x_reg       <= 16'd0;
      p_reg       <= 16'd0;
    end else begin
      state <= next_state;

      case (state)
        STATE_IDLE: begin
          done       <= 1'b0;
          cycle_cnt  <= 5'd0;
          n          <= 5'd0;
          max_profit <= 32'd0;
          if (start) begin
            // Latch inputs at start
            x_reg <= x;
            p_reg <= p;
          end
        end

        STATE_CALC: begin
          // Increment cycle count and bet index
          cycle_cnt <= cycle_cnt + 5'd1;

          // Update max_profit from combinational result
          max_profit <= max_profit_next;

          if (n < MAX_BETS)
            n <= n + 5'd1;
          else
            n <= n; // stay at MAX_BETS until transition to DONE

          // done will be asserted next state when STATE_DONE
          done <= 1'b0;
        end

        STATE_DONE: begin
          done <= 1'b1;
          // Keep max_profit stable; wait for new transaction
          if (!start) begin
            // prepare for potential next start
            n          <= 5'd0;
            cycle_cnt  <= 5'd0;
          end
        end

        default: begin
          state      <= STATE_IDLE;
          done       <= 1'b0;
          max_profit <= 32'd0;
          n          <= 5'd0;
          cycle_cnt  <= 5'd0;
        end
      endcase
    end
  end

endmodule