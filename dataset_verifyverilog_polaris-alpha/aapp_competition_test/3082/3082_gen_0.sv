module buffet_optimizer(
  input               clk,
  input               rst_n,
  input               start,
  input       [1:0]   dish_type [0:3],
  input       [7:0]   w_i      [0:3],
  input       [7:0]   t_i      [0:3],
  input       [7:0]   dt_i     [0:3],
  input       [7:0]   target_w,
  output reg  [15:0]  max_taste,
  output reg          impossible,
  output reg          done
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE            = 3'd0,
    ITERATE_DISHES  = 3'd1,
    CHECK_WEIGHT    = 3'd2,
    UPDATE          = 3'd3,
    DONE_STATE      = 3'd4
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [1:0]  dish_idx;            // 0..3
  reg [11:0] remaining_w;         // Q4.4 stored as 12-bit (0..4095)
  reg [23:0] max_taste_accum;     // internal accumulator Q8.8
  reg        any_taken;           // track if any tastiness added

  // Latched dish parameters for current dish
  reg [1:0]  cur_type;
  reg [7:0]  cur_w_q4_4;
  reg [7:0]  cur_t_q8_0;
  reg [7:0]  cur_dt_q8_0;

  // Intermediate values for per-dish computation
  reg [11:0] cur_w_q4_4_ext;      // extended weight

  // Discrete dish intermediates
  reg [11:0] N;                   // number of whole items (<= remaining_w / w_i)
  reg [23:0] disc_sum_taste;      // Q8.8
  reg [23:0] disc_w_used;         // Q4.4 in 24 bits (N * w_i)

  // Continuous dish intermediates
  reg [11:0] max_x_weight;        // from remaining weight (Q4.4)
  reg [23:0] t_over_dt_x16;       // (t_i << 4)/dt_i in Q4.4
  reg [11:0] x_q4_4;              // chosen X in Q4.4
  reg [31:0] cont_taste_tmp;      // temp
  reg [31:0] cont_x2;             // X^2 in Q8.8
  reg [23:0] cont_taste;          // final continuous taste Q8.8
  reg [23:0] cont_w_used;         // X in Q4.4 (extended)

  // Helper wires/regs
  reg        last_dish;
  reg        use_discrete;
  reg        use_continuous;

  // Combinational: determine if current dish is last
  always @(*) begin
    last_dish = (dish_idx == 2'd3);
  end

  // FSM: Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = ITERATE_DISHES;
      end

      ITERATE_DISHES: begin
        // move to CHECK_WEIGHT to process selected/latched dish
        next_state = CHECK_WEIGHT;
      end

      CHECK_WEIGHT: begin
        // After computing per-dish values, go to UPDATE
        next_state = UPDATE;
      end

      UPDATE: begin
        // After updating accumulators and indexes
        if (last_dish) begin
          next_state = DONE_STATE;
        end else begin
          next_state = ITERATE_DISHES;
        end
      end

      DONE_STATE: begin
        // Wait one cycle with done=1, then go idle
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= IDLE;
      dish_idx         <= 2'd0;
      remaining_w      <= 12'd0;
      max_taste_accum  <= 24'd0;
      max_taste        <= 16'd0;
      impossible       <= 1'b0;
      done             <= 1'b0;
      any_taken        <= 1'b0;
      cur_type         <= 2'd0;
      cur_w_q4_4       <= 8'd0;
      cur_t_q8_0       <= 8'd0;
      cur_dt_q8_0      <= 8'd0;
      cur_w_q4_4_ext   <= 12'd0;
      N                <= 12'd0;
      disc_sum_taste   <= 24'd0;
      disc_w_used      <= 24'd0;
      max_x_weight     <= 12'd0;
      t_over_dt_x16    <= 24'd0;
      x_q4_4           <= 12'd0;
      cont_taste_tmp   <= 32'd0;
      cont_x2          <= 32'd0;
      cont_taste       <= 24'd0;
      cont_w_used      <= 24'd0;
    end else begin
      state <= next_state;
      done  <= 1'b0; // default, pulsed only in DONE_STATE

      case (state)
        IDLE: begin
          if (start) begin
            // Initialize accumulators and state
            dish_idx        <= 2'd0;
            remaining_w     <= {4'd0, target_w}; // extend 8-bit Q4.4 to 12-bit
            max_taste_accum <= 24'd0;
            any_taken       <= 1'b0;
            impossible      <= 1'b0;
          end
        end

        ITERATE_DISHES: begin
          // Latch current dish parameters
          cur_type       <= dish_type[dish_idx];
          cur_w_q4_4     <= w_i[dish_idx];
          cur_t_q8_0     <= t_i[dish_idx];
          cur_dt_q8_0    <= dt_i[dish_idx];
          cur_w_q4_4_ext <= {4'd0, w_i[dish_idx]};
        end

        CHECK_WEIGHT: begin
          // Determine discrete or continuous handling
          use_discrete    <= (cur_type == 2'd0);
          use_continuous  <= (cur_type == 2'd1);

          // DISCRETE DISH CALCULATION
          // Guard against zero weight or no remaining capacity
          if (cur_type == 2'd0) begin
            if ((cur_w_q4_4_ext == 12'd0) || (remaining_w == 12'd0)) begin
              N              <= 12'd0;
              disc_sum_taste <= 24'd0;
              disc_w_used    <= 24'd0;
            end else begin
              // N = remaining_w / w_i (integer, using Q4.4 units)
              N <= remaining_w / cur_w_q4_4_ext;

              // Compute taste sum for discrete greedy picks:
              // sum = N*t - dt * N*(N-1)/2
              // All signals here t, dt are Q8.0, sum kept as Q8.8 (<<8)
              // Use extended intermediates
              // temp1 = N * t
              // temp2 = N*(N-1)/2
              // sum = (temp1 - dt * temp2) << 8
              if (remaining_w / cur_w_q4_4_ext == 0) begin
                disc_sum_taste <= 24'd0;
                disc_w_used    <= 24'd0;
              end else begin
                reg [23:0] temp1;
                reg [23:0] temp2;
                reg [23:0] temp3;
                temp1 = (remaining_w / cur_w_q4_4_ext) * cur_t_q8_0;
                temp2 = (remaining_w / cur_w_q4_4_ext);
                temp2 = temp2 * (temp2 - 1) >> 1;
                temp3 = cur_dt_q8_0 * temp2;
                if (temp1 > temp3)
                  disc_sum_taste <= (temp1 - temp3) << 8;
                else
                  disc_sum_taste <= 24'd0;
                disc_w_used <= (remaining_w / cur_w_q4_4_ext) * cur_w_q4_4_ext;
              end
            end
          end

          // CONTINUOUS DISH CALCULATION
          if (cur_type == 2'd1) begin
            // max_x_weight is how much we can take due to remaining weight (Q4.4)
            max_x_weight <= remaining_w;

            // Compute X_limit = t/dt in Q4.4 as (t << 4)/dt, guard dt!=0
            if (cur_dt_q8_0 != 8'd0) begin
              t_over_dt_x16 <= ({cur_t_q8_0,4'd0} * 16'd1) / cur_dt_q8_0; // (t<<4)/dt
            end else begin
              // If dt == 0, tastiness does not decay; for greedy, limited only by remaining weight
              t_over_dt_x16 <= 24'hFFFFFF; // effectively infinite
            end

            // Select X = min(max_x_weight, t_over_dt_x16)
            if (max_x_weight <= t_over_dt_x16[11:0])
              x_q4_4 <= max_x_weight;
            else
              x_q4_4 <= t_over_dt_x16[11:0];

            // Taste: (t*X - 0.5*dt*X^2) in Q8.8
            // t*X: Q8.0 * Q4.4 => Q12.4 => align to Q8.8 by <<4
            cont_taste_tmp = cur_t_q8_0 * x_q4_4;     // Q12.4
            cont_taste_tmp = cont_taste_tmp << 4;     // Q8.8

            // X^2: Q4.4 * Q4.4 = Q8.8
            cont_x2 = x_q4_4 * x_q4_4;                // Q8.8

            // 0.5*dt*X^2: dt(Q8.0)*X^2(Q8.8) = Q16.8; *0.5 => >>1 => Q16.7
            // Align to Q8.8 by >>? We'll approximate via >>9 (>>1 for 0.5 and >>8 to go from *X^2 Q8.8 to Q8.0 diff)
            // Implement: penalty = (dt * X^2) >> 9; (heuristic scaling)
            begin
              reg [31:0] penalty;
              penalty = (cur_dt_q8_0 * cont_x2) >> 9; // approx Q8.8
              if (cont_taste_tmp > penalty)
                cont_taste <= cont_taste_tmp - penalty;
              else
                cont_taste <= 24'd0;
            end

            cont_w_used <= x_q4_4; // Q4.4 consumed
          end
        end

        UPDATE: begin
          // Update accumulators and dish index based on type
          if (cur_type == 2'd0) begin
            // Discrete
            if (disc_w_used != 24'd0 && disc_sum_taste != 24'd0) begin
              any_taken       <= 1'b1;
              max_taste_accum <= max_taste_accum + disc_sum_taste;
              if (remaining_w >= disc_w_used[11:0])
                remaining_w <= remaining_w - disc_w_used[11:0];
              else
                remaining_w <= 12'd0;
            end
          end else if (cur_type == 2'd1) begin
            // Continuous
            if (cont_w_used != 24'd0 && cont_taste != 24'd0) begin
              any_taken       <= 1'b1;
              max_taste_accum <= max_taste_accum + cont_taste;
              if (remaining_w >= cont_w_used[11:0])
                remaining_w <= remaining_w - cont_w_used[11:0];
              else
                remaining_w <= 12'd0;
            end
          end

          // Advance dish index
          if (!last_dish) begin
            dish_idx <= dish_idx + 2'd1;
          end
        end

        DONE_STATE: begin
          // Determine outputs
          done       <= 1'b1;
          max_taste <= max_taste_accum[15:0];

          // If no tastiness taken or remaining_w still > 0 and no more dishes, mark impossible
          if (!any_taken || (remaining_w != 12'd0))
            impossible <= 1'b1;
          else
            impossible <= 1'b0;
        end

        default: ;
      endcase
    end
  end

endmodule