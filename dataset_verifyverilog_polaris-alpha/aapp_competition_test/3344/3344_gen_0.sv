module luggage_speed_calculator(
  input clk,
  input rst_n,
  input start,
  input [31:0] L_fixed,
  input [31:0] positions [0:7],
  input [2:0] num_items,
  output reg [31:0] speed_fixed,
  output reg done,
  output reg valid
);

  // Parameters (Q16.16)
  localparam [31:0] Q_ONE       = 32'h00010000; // 1.0
  localparam [31:0] MIN_SPEED   = 32'h00001999; // 0.1 (given)
  localparam [31:0] MAX_SPEED   = 32'h00A00000; // 10.0 (given)
  localparam [31:0] NO_FIKA_VAL = 32'hFFFFFFFF;

  // FSM states
  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_INIT   = 3'd1,
    S_SORT   = 3'd2,
    S_GAP    = 3'd3,
    S_DONE   = 3'd4
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [31:0] pos_reg [0:7];
  reg [2:0]  n_items_reg;

  // Sort control
  reg [3:0] i_idx; // up to 8
  reg [3:0] j_idx;

  // Swap wires
  reg [31:0] tmp;

  // Gap and speed computation
  reg        gap_phase_wrap;         // 0: processing adjacent gaps, 1: wrap gap
  reg [2:0]  gap_idx;                // index for adjacent gap

  reg [31:0] best_speed;            // current minimum of per-gap speeds
  reg        any_valid_gap;         // at least one valid speed found

  // Divider handshake
  reg        div_start;
  wire       div_busy;
  wire       div_done;
  reg [31:0] div_dividend;
  reg [31:0] div_divisor;
  wire [31:0] div_quotient;

  // Sequential state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Main sequential logic
  integer k;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done         <= 1'b0;
      valid        <= 1'b0;
      speed_fixed  <= 32'd0;
      n_items_reg  <= 3'd0;
      i_idx        <= 4'd0;
      j_idx        <= 4'd0;
      gap_phase_wrap <= 1'b0;
      gap_idx      <= 3'd0;
      best_speed   <= 32'hFFFFFFFF;
      any_valid_gap<= 1'b0;
      for (k = 0; k < 8; k = k + 1) begin
        pos_reg[k] <= 32'd0;
      end
      tmp          <= 32'd0;
      div_start    <= 1'b0;
      div_dividend <= 32'd0;
      div_divisor  <= 32'd0;
    end else begin
      // defaults
      div_start <= 1'b0;
      done      <= 1'b0;

      case (state)
        S_IDLE: begin
          if (start) begin
            // Latch inputs
            n_items_reg <= (num_items < 3'd1) ? 3'd1 : (num_items > 3'd8 ? 3'd8 : num_items);
            for (k = 0; k < 8; k = k + 1) begin
              pos_reg[k] <= positions[k];
            end
            best_speed    <= 32'hFFFFFFFF;
            any_valid_gap <= 1'b0;
            i_idx         <= 4'd0;
            j_idx         <= 4'd0;
            gap_idx       <= 3'd0;
            gap_phase_wrap<= 1'b0;
          end
        end

        S_INIT: begin
          // Start of sort: reset indices
          i_idx <= 4'd0;
          j_idx <= 4'd0;
        end

        S_SORT: begin
          // Simple bubble sort unrolled over cycles
          // Only sort the first n_items_reg entries; others ignored
          if (i_idx < n_items_reg) begin
            if (j_idx + 1 < n_items_reg - i_idx) begin
              // compare and swap pos_reg[j_idx], pos_reg[j_idx+1]
              if (pos_reg[j_idx] > pos_reg[j_idx + 1]) begin
                tmp                 <= pos_reg[j_idx];
                pos_reg[j_idx]      <= pos_reg[j_idx + 1];
                pos_reg[j_idx + 1]  <= tmp;
              end
              j_idx <= j_idx + 1;
            end else begin
              j_idx <= 4'd0;
              i_idx <= i_idx + 1;
            end
          end
        end

        S_GAP: begin
          // Gap and speed computation using iterative divider
          if (!div_busy && !div_done) begin
            // Prepare next division if any gap left
            if (!gap_phase_wrap) begin
              if (gap_idx < n_items_reg) begin
                // Adjacent gap between pos_reg[gap_idx] and pos_reg[gap_idx+1]
                // For last adjacent (gap_idx == n_items_reg-1) we will handle wrap phase instead
                if (gap_idx < n_items_reg - 1) begin
                  // gap = pos[i+1] - pos[i]
                  if (pos_reg[gap_idx + 1] > pos_reg[gap_idx] + Q_ONE) begin
                    // G - 1.0 > 0
                    div_dividend <= {L_fixed,16'd0}; // align for Q16.16 divide by Q16.16
                    div_divisor  <= (pos_reg[gap_idx + 1] - pos_reg[gap_idx] - Q_ONE);
                    div_start    <= 1'b1;
                  end else begin
                    // Invalid (gap <= 1.0) -> no safe speed for this gap, skip
                    gap_idx <= gap_idx + 1;
                  end
                end else begin
                  // reached last index; switch to wrap phase
                  gap_phase_wrap <= 1'b1;
                end
              end else begin
                gap_phase_wrap <= 1'b1;
              end
            end else begin
              // wrap-around gap between last and first: G = (L + pos[0]) - pos[last]
              if (n_items_reg != 0) begin
                reg [31:0] last_pos;
                reg [31:0] first_pos;
                reg [31:0] gap_w;
                last_pos  = pos_reg[n_items_reg - 1];
                first_pos = pos_reg[0];
                gap_w = (L_fixed + first_pos);
                if (gap_w > last_pos + Q_ONE) begin
                  // G - 1.0 > 0
                  div_dividend <= {L_fixed,16'd0};
                  div_divisor  <= (gap_w - last_pos - Q_ONE);
                  div_start    <= 1'b1;
                end else begin
                  // No valid gaps -> go to done, result NO_FIKA
                  gap_phase_wrap <= 1'b0; // not really needed
                end
              end
            end
          end else if (div_done) begin
            // Division result available: div_quotient is Q16.16 speed
            // Update best_speed (minimum) and validity
            if (div_quotient != 32'd0) begin
              any_valid_gap <= 1'b1;
              if (div_quotient < best_speed)
                best_speed <= div_quotient;
            end

            if (!gap_phase_wrap) begin
              // move to next gap
              gap_idx <= gap_idx + 1;
            end else begin
              // wrap gap processed; all gaps done
              gap_phase_wrap <= 1'b0;
            end
          end
        end

        S_DONE: begin
          done <= 1'b1;
          // Apply final range checks
          if (!any_valid_gap) begin
            valid       <= 1'b0;
            speed_fixed <= NO_FIKA_VAL;
          end else begin
            // Clamp best_speed to within [MIN_SPEED, MAX_SPEED]
            if (best_speed < MIN_SPEED || best_speed > MAX_SPEED) begin
              valid       <= 1'b0;
              speed_fixed <= NO_FIKA_VAL;
            end else begin
              valid       <= 1'b1;
              speed_fixed <= best_speed;
            end
          end
        end

        default: begin
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) next_state = S_INIT;
      end
      S_INIT: begin
        next_state = S_SORT;
      end
      S_SORT: begin
        // Finish when i_idx completed for all
        if (i_idx >= n_items_reg) next_state = S_GAP;
      end
      S_GAP: begin
        // Termination condition: all gaps processed
        // We consider completion when wrap-phase is done and no div is busy
        if (!div_busy && !div_done && gap_phase_wrap == 1'b0 && (gap_idx >= n_items_reg || n_items_reg <= 1)) begin
          next_state = S_DONE;
        end
      end
      S_DONE: begin
        // Wait for start to deassert and possibly new start
        if (!start) next_state = S_IDLE;
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Simple iterative divider (unsigned), 32-bit / 32-bit -> 32-bit quotient
  // Latency: 32 cycles max after div_start
  reg [5:0]  div_cnt;
  reg [63:0] div_rem;
  reg [31:0] div_div;
  reg [31:0] div_q;
  reg        div_active;

  assign div_busy    = div_active;
  assign div_done    = (!div_active && (div_cnt == 6'd33));
  assign div_quotient= div_q;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      div_cnt    <= 6'd0;
      div_rem    <= 64'd0;
      div_div    <= 32'd0;
      div_q      <= 32'd0;
      div_active <= 1'b0;
    end else begin
      if (div_start && !div_active && (div_divisor != 32'd0)) begin
        // Initialize divider
        div_active <= 1'b1;
        div_cnt    <= 6'd0;
        div_div    <= div_divisor;
        div_q      <= 32'd0;
        div_rem    <= 64'd0;
      end else if (div_active) begin
        if (div_cnt < 6'd32) begin
          div_rem = {div_rem[62:0], div_dividend[31-div_cnt]};
          if (div_rem[63:32] >= div_div) begin
            div_rem[63:32] = div_rem[63:32] - div_div;
            div_q[31-div_cnt] = 1'b1;
          end else begin
            div_q[31-div_cnt] = 1'b0;
          end
          div_cnt <= div_cnt + 1'b1;
        end else begin
          div_active <= 1'b0;
          div_cnt    <= 6'd33; // mark done
        end
      end else if (!div_active && div_cnt == 6'd33 && !div_start) begin
        // hold done one cycle; next usage will overwrite
      end
    end
  end

endmodule