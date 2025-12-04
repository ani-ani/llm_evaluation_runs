module lemonade_trader(
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0]  color_ids [0:7],
  input  [31:0] rates     [0:7],
  input  [2:0]  num_children,
  output reg [31:0] max_blue_q16,
  output reg       done
);

  // Color encodings
  localparam [3:0] COLOR_PINK = 4'd0;
  localparam [3:0] COLOR_BLUE = 4'd1;

  // Q16.16 constants
  localparam [31:0] ONE_Q16  = 32'h0001_0000; // 1.0
  localparam [31:0] TEN_Q16  = 32'h000A_0000; // 10.0

  // FSM states
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_INIT      = 3'd1,
    S_LOAD      = 3'd2,
    S_COMPUTE   = 3'd3,
    S_FINALIZE  = 3'd4,
    S_DONE      = 3'd5
  } state_t;

  state_t state, next_state;

  // DP arrays: best amount (Q16.16) per color for current and next step
  reg [31:0] dp_curr [0:15];
  reg [31:0] dp_next [0:15];

  // Number of steps/children in this run
  reg [2:0] steps;

  // Loop indices
  reg [3:0] init_idx;      // 0..15 for initialization
  reg [3:0] color_idx;     // 0..15 when scanning colors
  reg [2:0] trade_idx;     // 0..7 when scanning children

  // Control
  reg [2:0] step_ctr;      // up to 7 (for 8 steps)
  reg       do_swap_dp;    // signal to copy dp_next to dp_curr

  // Working registers for computations
  reg [31:0] base_amount;
  reg [31:0] rate_q16;
  reg [63:0] mult_res;
  reg [31:0] new_amount;

  // Max tracker
  reg [31:0] max_blue_next;

  // Combinational helpers
  wire [3:0] cid_at_trade = color_ids[trade_idx];

  // FSM next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end
      S_INIT: begin
        next_state = S_LOAD;
      end
      S_LOAD: begin
        // After initializing dp_curr with initial pink and zeros, proceed
        next_state = (steps == 3'd0) ? S_FINALIZE : S_COMPUTE;
      end
      S_COMPUTE: begin
        // Iterate through: for each step, for each color, for each trade
        // State transitions are controlled in sequential always block
        // Here we simply remain until sequential logic moves us forward
        next_state = state;
      end
      S_FINALIZE: begin
        next_state = S_DONE;
      end
      S_DONE: begin
        // Stay done until a new start pulse
        if (start)
          next_state = S_INIT;
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= S_IDLE;
      done          <= 1'b0;
      max_blue_q16  <= 32'd0;
      steps         <= 3'd0;
      step_ctr      <= 3'd0;
      init_idx      <= 4'd0;
      color_idx     <= 4'd0;
      trade_idx     <= 3'd0;
      do_swap_dp    <= 1'b0;
      for (i = 0; i < 16; i = i + 1) begin
        dp_curr[i] <= 32'd0;
        dp_next[i] <= 32'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        // Wait for start
        S_IDLE: begin
          done         <= 1'b0;
          max_blue_q16 <= 32'd0;
          if (start) begin
            steps    <= (num_children > 3'd8) ? 3'd8 : num_children; // clamp safety
            step_ctr <= 3'd0;
            init_idx <= 4'd0;
          end
        end

        // Initialize DP arrays
        S_INIT: begin
          // Clear all colors
          dp_curr[init_idx] <= 32'd0;
          dp_next[init_idx] <= 32'd0;
          if (init_idx == 4'd15) begin
            // After clearing all, set initial pink amount
            dp_curr[COLOR_PINK] <= ONE_Q16;
          end
          if (init_idx < 4'd15)
            init_idx <= init_idx + 4'd1;
        end

        // Load done, move to compute or finalize if zero steps
        S_LOAD: begin
          // Nothing additional; transitions handled by next_state
          color_idx  <= 4'd0;
          trade_idx  <= 3'd0;
          do_swap_dp <= 1'b0;
        end

        // Core DP computation over up to 8 steps
        S_COMPUTE: begin
          // We perform nested loops across cycles:
          // for step_ctr in [0, steps-1]:
          //   for color_idx in [0,15]:
          //     for trade_idx in [0, steps-1]:
          //       relax transitions

          // Default: maintain
          do_swap_dp <= 1'b0;

          // Base amount at current color
          base_amount = dp_curr[color_idx];

          // Only attempt trades if base_amount > 0 and trade_idx < steps
          if (base_amount != 32'd0 && trade_idx < steps) begin
            // For simplicity, treat each provided trade as mapping from its color_id to BLUE.
            // If current color matches trade's color_id, we can trade to BLUE at given rate.
            if (COLOR_PINK == color_ids[trade_idx] && color_idx == COLOR_PINK) begin
              // trade from pink to blue
              rate_q16   = rates[trade_idx];
              mult_res   = base_amount * rate_q16; // Q16.16 * Q16.16 = Q32.32
              new_amount = mult_res[47:16];        // back to Q16.16
              if (new_amount > dp_next[COLOR_BLUE]) begin
                dp_next[COLOR_BLUE] <= new_amount;
              end
              // Also propagate best known amounts forward (no-trade carry):
              if (dp_next[color_idx] < base_amount)
                dp_next[color_idx] <= base_amount;
            end else if (color_ids[trade_idx] == color_idx && color_idx != COLOR_BLUE) begin
              // trade from this color to blue
              rate_q16   = rates[trade_idx];
              mult_res   = base_amount * rate_q16;
              new_amount = mult_res[47:16];
              if (new_amount > dp_next[COLOR_BLUE]) begin
                dp_next[COLOR_BLUE] <= new_amount;
              end
              if (dp_next[color_idx] < base_amount)
                dp_next[color_idx] <= base_amount;
            end else begin
              // No applicable trade: just carry forward the current amount
              if (dp_next[color_idx] < base_amount)
                dp_next[color_idx] <= base_amount;
            end
          end else begin
            // No base or beyond steps: just carry dp_curr forward
            if (dp_next[color_idx] < dp_curr[color_idx])
              dp_next[color_idx] <= dp_curr[color_idx];
          end

          // Advance inner-most loop index
          if (trade_idx + 3'd1 < steps) begin
            trade_idx <= trade_idx + 3'd1;
          end else begin
            // Done all trades for this color; move to next color
            trade_idx <= 3'd0;
            if (color_idx < 4'd15) begin
              color_idx <= color_idx + 4'd1;
            end else begin
              // Completed all colors for this step: swap dp_next into dp_curr
              do_swap_dp <= 1'b1;
              color_idx  <= 4'd0;
            end
          end

          // When a step is completed, swap and maybe move to finalize
          if (do_swap_dp) begin
            // Copy dp_next to dp_curr and clear dp_next
            for (i = 0; i < 16; i = i + 1) begin
              dp_curr[i] <= dp_next[i];
              dp_next[i] <= 32'd0;
            end

            // Increment step counter
            if (step_ctr + 3'd1 < steps) begin
              step_ctr <= step_ctr + 3'd1;
            end else begin
              // All steps done
              step_ctr <= step_ctr;
              state    <= S_FINALIZE;
            end
          end
        end

        // Finalization: select max in BLUE and cap at 10.0 litres
        S_FINALIZE: begin
          max_blue_next = dp_curr[COLOR_BLUE];
          // Cap at TEN_Q16
          if (max_blue_next > TEN_Q16)
            max_blue_q16 <= TEN_Q16;
          else
            max_blue_q16 <= max_blue_next;

          done <= 1'b1;
        end

        // DONE state: hold outputs until next start
        S_DONE: begin
          if (start) begin
            done         <= 1'b0;
            max_blue_q16 <= 32'd0;
            steps        <= (num_children > 3'd8) ? 3'd8 : num_children;
            step_ctr     <= 3'd0;
            init_idx     <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
              dp_curr[i] <= 32'd0;
              dp_next[i] <= 32'd0;
            end
          end
        end

        default: begin
          // safety
        end
      endcase
    end
  end

endmodule