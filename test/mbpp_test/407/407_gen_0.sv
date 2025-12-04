module next_bigger_num (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [9:0]  num,
  output logic [9:0]  next_num,
  output logic        done,
  output logic        no_bigger
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE       = 3'd0,
    FIND_PIVOT = 3'd1,
    FIND_MIN   = 3'd2,
    SWAP_SORT  = 3'd3,
    VALID      = 3'd4
  } state_t;

  state_t state, next_state;

  // BCD digits (4 bits each, but only 0-9 used)
  logic [3:0] h, t, u;          // current working digits
  logic [3:0] h_nxt, t_nxt, u_nxt;

  // Latched original digits for stable processing
  logic [3:0] h_reg, t_reg, u_reg;

  // Control flags
  logic       pivot_found;
  logic       pivot_is_h;        // 1: pivot at hundreds, 0: pivot at tens

  // Min-greater selection (FIND_MIN)
  logic [3:0] min_dig;
  logic [1:0] min_pos;           // 0: none, 1: pos1, 2: pos2

  // Sequential: state and registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      h_reg      <= 4'd0;
      t_reg      <= 4'd0;
      u_reg      <= 4'd0;
      h          <= 4'd0;
      t          <= 4'd0;
      u          <= 4'd0;
      next_num   <= 10'd0;
      done       <= 1'b0;
      no_bigger  <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done      <= 1'b0;
          no_bigger <= 1'b0;
          if (start) begin
            // Convert num (0-999) into three BCD digits
            // Using simple combinational division by constants
            automatic logic [9:0] tmp_num;
            automatic logic [3:0] hh, tt, uu;
            tmp_num = num;
            hh      = tmp_num / 10'd100;
            tmp_num = tmp_num - (hh * 10'd100);
            tt      = tmp_num / 10'd10;
            uu      = tmp_num - (tt * 10'd10);

            h_reg <= hh;
            t_reg <= tt;
            u_reg <= uu;

            h <= hh;
            t <= tt;
            u <= uu;
          end
        end

        FIND_PIVOT: begin
          // Digits already in h,t,u from previous cycle
          // No register updates here except hold
          h <= h;
          t <= t;
          u <= u;
        end

        FIND_MIN: begin
          // Use previously latched h,t,u; compute min_dig/min_pos combinationally
          h <= h;
          t <= t;
          u <= u;
        end

        SWAP_SORT: begin
          // Apply computed next digits (h_nxt,t_nxt,u_nxt)
          h <= h_nxt;
          t <= t_nxt;
          u <= u_nxt;
        end

        VALID: begin
          // Form next_num from final BCD digits
          next_num  <= (h * 10'd100) + (t * 10'd10) + u;
          done      <= 1'b1;
          // no_bigger driven from control logic in next_state
        end

        default: begin
          // Safe defaults
          h <= h;
          t <= t;
          u <= u;
        end
      endcase
    end
  end

  // Combinational next-state logic and pivot/min computations
  always_comb begin
    // Default
    next_state   = state;
    pivot_found  = 1'b0;
    pivot_is_h   = 1'b0;
    min_dig      = 4'd0;
    min_pos      = 2'd0;
    h_nxt        = h;
    t_nxt        = t;
    u_nxt        = u;

    case (state)
      IDLE: begin
        if (start) begin
          // After capturing digits, move to pivot search
          next_state = FIND_PIVOT;
        end
      end

      FIND_PIVOT: begin
        // All comparisons in parallel:
        // Check rightmost pair (t,u)
        if (t < u) begin
          pivot_found = 1'b1;
          pivot_is_h  = 1'b0;  // pivot at tens
        end
        // If not found, check (h,t)
        else if (h < t) begin
          pivot_found = 1'b1;
          pivot_is_h  = 1'b1;  // pivot at hundreds
        end

        if (!pivot_found) begin
          // No pivot -> no bigger permutation exists
          next_state = VALID;  // will assert no_bigger via state transition
        end else begin
          next_state = FIND_MIN;
        end
      end

      FIND_MIN: begin
        // Determine smallest digit > pivot in the suffix, using parallel compares
        if (pivot_is_h) begin
          // Pivot at hundreds digit: suffix = {t,u}
          // Candidates: t,u if > h
          // Evaluate both in parallel, pick smallest > h
          logic cand_t_valid, cand_u_valid;
          logic [3:0] cand_t, cand_u;

          cand_t_valid = (t > h);
          cand_u_valid = (u > h);
          cand_t       = t;
          cand_u       = u;

          if (cand_t_valid && cand_u_valid) begin
            // both valid: choose smaller
            if (cand_t <= cand_u) begin
              min_dig = cand_t; min_pos = 2'd1; // position of t
            end else begin
              min_dig = cand_u; min_pos = 2'd2; // position of u
            end
          end else if (cand_t_valid) begin
            min_dig = cand_t; min_pos = 2'd1;
          end else if (cand_u_valid) begin
            min_dig = cand_u; min_pos = 2'd2;
          end else begin
            // Should not occur if pivot_is_h was valid, but guard anyway
            min_dig = 4'd0; min_pos = 2'd0;
          end
        end else begin
          // Pivot at tens digit: suffix = {u}
          // Only candidate: u if > t
          if (u > t) begin
            min_dig = u; min_pos = 2'd2; // position of u
          end else begin
            min_dig = 4'd0; min_pos = 2'd0; // safety
          end
        end

        next_state = SWAP_SORT;
      end

      SWAP_SORT: begin
        // Use pivot_is_h and min_pos to swap and sort tail via hardwired network
        if (pivot_is_h) begin
          // Pivot at h, suffix {t,u}, min_dig is at min_pos
          // After swap: h' = min_dig, suffix sorted ascending
          if (min_pos == 2'd1) begin
            // min at t: swap h<->t, then sort {h_old,u}
            // Efficient wired form:
            // new_h = t;
            // remaining digits: {h,u}; output ascending
            h_nxt = t;
            if (h <= u) begin
              t_nxt = h;
              u_nxt = u;
            end else begin
              t_nxt = u;
              u_nxt = h;
            end
          end else if (min_pos == 2'd2) begin
            // min at u: swap h<->u, then sort {h_old,t}
            h_nxt = u;
            if (h <= t) begin
              t_nxt = h;
              u_nxt = t;
            end else begin
              t_nxt = t;
              u_nxt = h;
            end
          end else begin
            // safety fall-back: no change
            h_nxt = h;
            t_nxt = t;
            u_nxt = u;
          end
        end else begin
          // Pivot at t, suffix {u}; min_dig at u
          // Just swap t and u, suffix of one element is trivially sorted
          if (min_pos == 2'd2) begin
            h_nxt = h;
            t_nxt = u;
            u_nxt = t;
          end else begin
            h_nxt = h;
            t_nxt = t;
            u_nxt = u;
          end
        end

        next_state = VALID;
      end

      VALID: begin
        // Indicate whether a bigger number existed.
        // If we arrived here directly from FIND_PIVOT without pivot_found,
        // then no_bigger must be 1. Otherwise 0.
        // We derive this via looking back implicitly: if there was no swap/sort.
        // For strict control, no_bigger set here based on check of permutations.
        // Recompute pivot condition combinationally using final digits vs original.

        // Default keep values from sequential always_ff
        // Determine no_bigger purely by absence of any greater permutation:
        // If (h_reg,t_reg,u_reg) >= (h,t,u) lexicographically, then no_bigger=1
        // This is safe because when pivot existed, result must be strictly greater.
        if ({h_reg,t_reg,u_reg} >= {h,t,u}) begin
          no_bigger = 1'b1;
        end else begin
          no_bigger = 1'b0;
        end

        // Stay in VALID until next start; done is held in seq block
        if (start) begin
          next_state = FIND_PIVOT; // new transaction after IDLE-like capture
        end else begin
          next_state = VALID;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule
