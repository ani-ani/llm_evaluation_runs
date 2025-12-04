module max_card_damage(
  input clk,
  input rst_n,
  input start,
  input [3:0] jiro_cnt,
  input [3:0][15:0] j_strength,
  input [3:0] j_type,
  input [3:0] ciel_cnt,
  input [3:0][15:0] c_strength,
  output reg [15:0] damage,
  output reg done
);

  // FSM states
  typedef enum logic [2:0] {
    IDLE        = 3'd0,
    SORT_JIRO   = 3'd1,
    SORT_CIEL   = 3'd2,
    CALC_STRAT1 = 3'd3,
    CALC_STRAT2 = 3'd4,
    DONE        = 3'd5
  } state_t;

  state_t state, next_state;

  // Internal registers for sorted cards
  reg [15:0] jiro_s[3:0];
  reg       jiro_t[3:0]; // 0=DEF,1=ATK aligned with jiro_s
  reg [15:0] ciel_s[3:0];

  // Control registers
  reg [4:0] cycle_cnt;      // to track latency vs requirement if needed
  reg [2:0] sort_i;         // bubble sort outer index
  reg [2:0] sort_j;         // bubble sort inner index

  // Strategy accumulators (use wide to avoid overflow, saturate later)
  reg [17:0] strat1_damage_acc; // up to ~4*65535 fits in <18 bits
  reg [17:0] strat2_damage_acc;

  // Internal working registers for calculations
  reg [3:0] jiro_cnt_r;
  reg [3:0] ciel_cnt_r;

  integer k;

  // Combinational next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = SORT_JIRO;
      end

      SORT_JIRO: begin
        // complete bubble passes when sort_i reaches 3 and sort_j reaches 2
        if ((sort_i == 3) && (sort_j == 3)) begin
          next_state = SORT_CIEL;
        end
      end

      SORT_CIEL: begin
        if ((sort_i == 3) && (sort_j == 3)) begin
          next_state = CALC_STRAT1;
        end
      end

      CALC_STRAT1: begin
        // single-cycle computation for this small problem
        next_state = CALC_STRAT2;
      end

      CALC_STRAT2: begin
        // single-cycle computation
        next_state = DONE;
      end

      DONE: begin
        if (start) next_state = SORT_JIRO;
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      damage <= 16'd0;
      cycle_cnt <= 5'd0;
      strat1_damage_acc <= 18'd0;
      strat2_damage_acc <= 18'd0;
      jiro_cnt_r <= 4'd0;
      ciel_cnt_r <= 4'd0;
      sort_i <= 3'd0;
      sort_j <= 3'd0;
      for (k = 0; k < 4; k = k + 1) begin
        jiro_s[k] <= 16'd0;
        jiro_t[k] <= 1'b0;
        ciel_s[k] <= 16'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          cycle_cnt <= 5'd0;
          strat1_damage_acc <= 18'd0;
          strat2_damage_acc <= 18'd0;
          sort_i <= 3'd0;
          sort_j <= 3'd0;
          if (start) begin
            // latch inputs
            jiro_cnt_r <= (jiro_cnt > 4) ? 4 : jiro_cnt;
            ciel_cnt_r <= (ciel_cnt > 4) ? 4 : ciel_cnt;
            // initialize local arrays (pad unused with zeros)
            for (k = 0; k < 4; k = k + 1) begin
              jiro_s[k] <= j_strength[k];
              jiro_t[k] <= j_type[k];
              ciel_s[k] <= c_strength[k];
            end
          end
        end

        SORT_JIRO: begin
          cycle_cnt <= cycle_cnt + 5'd1;
          // Bubble sort jiro_s and jiro_t in ascending order of strength
          // Only sort indices < jiro_cnt_r; others can stay as is.
          if (jiro_cnt_r > 1) begin
            if (sort_i < 3) begin
              if (sort_j < 3) begin
                if ((sort_j < (jiro_cnt_r - 1)) && (sort_j + 1 < jiro_cnt_r)) begin
                  if (jiro_s[sort_j] > jiro_s[sort_j+1]) begin
                    // swap strength
                    reg [15:0] tmp_s;
                    reg        tmp_t;
                    tmp_s = jiro_s[sort_j];
                    jiro_s[sort_j] = jiro_s[sort_j+1];
                    jiro_s[sort_j+1] = tmp_s;
                    // swap type
                    tmp_t = jiro_t[sort_j];
                    jiro_t[sort_j] = jiro_t[sort_j+1];
                    jiro_t[sort_j+1] = tmp_t;
                  end
                end
                sort_j <= sort_j + 3'd1;
              end else begin
                sort_j <= 3'd0;
                sort_i <= sort_i + 3'd1;
              end
            end else begin
              // done
              sort_i <= 3'd3;
              sort_j <= 3'd3;
            end
          end else begin
            // nothing to sort
            sort_i <= 3'd3;
            sort_j <= 3'd3;
          end
        end

        SORT_CIEL: begin
          cycle_cnt <= cycle_cnt + 5'd1;
          // reuse sort_i, sort_j for ciel_s sorting (ascending)
          if (sort_i == 3 && sort_j == 3) begin
            // initialize for Ciel sort
            sort_i <= 3'd0;
            sort_j <= 3'd0;
          end else begin
            if (ciel_cnt_r > 1) begin
              if (sort_i < 3) begin
                if (sort_j < 3) begin
                  if ((sort_j < (ciel_cnt_r - 1)) && (sort_j + 1 < ciel_cnt_r)) begin
                    if (ciel_s[sort_j] > ciel_s[sort_j+1]) begin
                      reg [15:0] tmp_cs;
                      tmp_cs = ciel_s[sort_j];
                      ciel_s[sort_j] = ciel_s[sort_j+1];
                      ciel_s[sort_j+1] = tmp_cs;
                    end
                  end
                  sort_j <= sort_j + 3'd1;
                end else begin
                  sort_j <= 3'd0;
                  sort_i <= sort_i + 3'd1;
                end
              end else begin
                sort_i <= 3'd3;
                sort_j <= 3'd3;
              end
            end else begin
              sort_i <= 3'd3;
              sort_j <= 3'd3;
            end
          end
        end

        CALC_STRAT1: begin
          cycle_cnt <= cycle_cnt + 5'd1;
          // Strategy 1: Destroy DEF then ATK
          // Copy sorted arrays into local temporaries for clarity
          integer i, j;
          reg [17:0] acc;
          reg [3:0] used_c;
          reg [3:0] def_idx;
          reg [3:0] atk_idx;
          acc = 18'd0;
          used_c = 4'd0;

          // 1) Destroy DEF cards greedily: smallest DEF with smallest Ciel >= DEF
          // Find DEFs in jiro_s/jiro_t (sorted by strength asc)
          for (i = 0; i < 4; i = i + 1) begin
            if (i < jiro_cnt_r && jiro_t[i] == 1'b0) begin
              // DEF card
              // find smallest unused Ciel card that can beat it
              reg found;
              found = 1'b0;
              for (j = 0; j < 4; j = j + 1) begin
                if (!found && j < ciel_cnt_r) begin
                  if ( (used_c & (4'b0001 << j)) == 0 && ciel_s[j] >= jiro_s[i]) begin
                    used_c = used_c | (4'b0001 << j);
                    found = 1'b0; // mark then exit next
                    found = 1'b1;
                  end
                end
              end
            end
          end

          // 2) Use remaining Ciel cards from weakest to strongest to hit ATK cards from weakest to strongest
          // Any remaining Ciel card applied to ATK card jiro_s[atk_idx] if ciel > atk, damage += ciel - atk
          // Build ATK index list (ascending)
          for (i = 0; i < 4; i = i + 1) begin
            // nothing: we'll use indexes directly
          end

          for (i = 0; i < 4; i = i + 1) begin
            if (i < ciel_cnt_r && (used_c & (4'b0001 << i)) == 0) begin
              // this Ciel card is free
              // find next ATK card not yet matched (we don't track per-card usage, we just advance)
              reg matched;
              matched = 1'b0;
              for (j = 0; j < 4 && !matched; j = j + 1) begin
                if (j < jiro_cnt_r && jiro_t[j] == 1'b1) begin
                  // try to apply: best is to target weakest available ATK sequentially
                  // We need a simple consumption model: use each ATK at most once.
                  // Implement as we "invalidate" matched ATK by setting type to DEF temporarily in this local block.
                end
              end
            end
          end

          // Because true per-card consumption is complex inside a single always block using temp regs,
          // implement explicit small matching arrays.
        end

        CALC_STRAT2: begin
          cycle_cnt <= cycle_cnt + 5'd1;
          // Strategy 2: Directly attack ATK cards with strongest Ciel cards
          // Implementation moved to a separate block below for clarity.
        end

        DONE: begin
          // Hold result, done stays high until next start
          cycle_cnt <= cycle_cnt + 5'd1;
          if (start) begin
            done <= 1'b0;
          end else begin
            done <= 1'b1;
          end
        end
      endcase
    end
  end

  // To keep code synthesizable and clear, implement CALC_STRAT1 and CALC_STRAT2
  // in separate clocked blocks guarded by state.

  // Helper: saturate 18-bit to 16-bit
  function automatic [15:0] sat16(input [17:0] v);
    begin
      if (v[17:16] != 2'b00) sat16 = 16'hFFFF;
      else sat16 = v[15:0];
    end
  endfunction

  // CALC_STRAT1 implementation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      strat1_damage_acc <= 18'd0;
    end else if (state == CALC_STRAT1) begin
      integer i, j;
      reg [3:0] used_c;          // bitmask for used Ciel cards in this strategy
      reg [3:0] used_atk;        // bitmask for used ATK Jiro cards
      reg [17:0] acc;

      used_c = 4'd0;
      used_atk = 4'd0;
      acc = 18'd0;

      // 1) Destroy DEF cards: use smallest sufficient Ciel card for each DEF
      for (i = 0; i < 4; i = i + 1) begin
        if (i < jiro_cnt_r && jiro_t[i] == 1'b0) begin
          // DEF card
          reg found;
          found = 1'b0;
          for (j = 0; j < 4; j = j + 1) begin
            if (!found && j < ciel_cnt_r) begin
              if (((used_c & (4'b0001 << j)) == 0) && (ciel_s[j] >= jiro_s[i])) begin
                used_c = used_c | (4'b0001 << j);
                found = 1'b1;
              end
            end
          end
        end
      end

      // 2) Attack ATK cards with remaining Ciel cards.
      // Use remaining Ciel from weakest to strongest against ATK from weakest to strongest.
      for (i = 0; i < 4; i = i + 1) begin
        if (i < ciel_cnt_r && ((used_c & (4'b0001 << i)) == 0)) begin
          // free Ciel card
          for (j = 0; j < 4; j = j + 1) begin
            if (j < jiro_cnt_r && jiro_t[j] == 1'b1 && ((used_atk & (4'b0001 << j)) == 0)) begin
              // candidate ATK card
              if (ciel_s[i] > jiro_s[j]) begin
                acc = acc + (ciel_s[i] - jiro_s[j]);
                used_atk = used_atk | (4'b0001 << j);
                // move to next Ciel card
                j = 4; // break
              end
            end
          end
        end
      end

      strat1_damage_acc <= acc;
    end
  end

  // CALC_STRAT2 implementation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      strat2_damage_acc <= 18'd0;
    end else if (state == CALC_STRAT2) begin
      integer i, j;
      reg [3:0] used_c;
      reg [3:0] used_atk;
      reg [17:0] acc;

      used_c = 4'd0;
      used_atk = 4'd0;
      acc = 18'd0;

      // Strategy 2 description (standard solution for this problem):
      // Use strongest Ciel cards to attack strongest Jiro ATK cards (no DEF consideration),
      // in descending order, gaining (ciel - jiro_atk) when positive.
      // 1) Collect ATK indices in ascending order (already sorted), then traverse from strongest.

      // Outer loop: Ciel from strongest to weakest
      for (i = 3; i >= 0; i = i - 1) begin
        if (i < ciel_cnt_r) begin
          // For each Ciel card, try to match with strongest remaining ATK Jiro card
          for (j = 3; j >= 0; j = j - 1) begin
            if (j < jiro_cnt_r && jiro_t[j] == 1'b1 && ((used_atk & (4'b0001 << j)) == 0)) begin
              if (ciel_s[i] > jiro_s[j]) begin
                acc = acc + (ciel_s[i] - jiro_s[j]);
                used_atk = used_atk | (4'b0001 << j);
                j = -1; // break
              end
            end
          end
        end
      end

      strat2_damage_acc <= acc;
    end
  end

  // Final damage selection and done control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      damage <= 16'd0;
      done <= 1'b0;
    end else begin
      if (state == DONE && next_state != DONE) begin
        // entering DONE state: choose max of strat1 and strat2 with saturation
        reg [17:0] d1;
        reg [17:0] d2;
        d1 = strat1_damage_acc;
        d2 = strat2_damage_acc;
        if (d1 >= d2) damage <= sat16(d1);
        else damage <= sat16(d2);
        done <= 1'b1;
      end else if (state == IDLE && start) begin
        done <= 1'b0;
      end
    end
  end

endmodule