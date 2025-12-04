module longest_non_decreasing(
  input clk,                // clock signal
  input rst_n,              // active-low reset
  input start,              // start computation
  input [3:0] n,            // array size (1-8)
  input [3:0] T,            // repetition count (1-16)
  input [8:0] a [0:7],      // input array elements (9 bits each)
  output reg [7:0] result,  // max sequence length (8 bits)
  output reg done            // high when computation complete
);

  // Constants
  localparam MAX_REP = 16;
  localparam MAX_N   = 8;
  localparam MAX_LEN = MAX_REP * MAX_N; // 128
  localparam LOG2_MAX_LEN = 7;          // $clog2(128)

  // State machine
  typedef enum logic [1:0] { IDLE = 2'b00, RUN = 2'b01, FINISH = 2'b10 } state_t;
  state_t state, state_next;

  // Control/iteration state
  reg [3:0] rep, rep_next;             // current repetition (0..MIN(T,16)-1)
  reg [3:0] idx, idx_next;             // index within a[0..n-1]
  reg [6:0] pos, pos_next;             // position in extended buffer (0..rep*n + idx - 1)
  reg [7:0] best, best_next;           // current global max length
  reg [7:0] lcss_reg, lcss_next;       // per-element LNDS length (updated at 2nd phase of each element)
  reg [7:0] waddr_reg, waddr_next;     // write address for max_count (equals pos after lcss computed)
  reg has_result, has_result_next;     // latches that result is valid in FINISH

  // DP table: max_count[0..pos-1] length per position in extended buffer
  reg [7:0] max_count [0:MAX_LEN-1];
  integer i;

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      rep <= 4'd0;
      idx <= 4'd0;
      pos <= 7'd0;
      best <= 8'd0;
      lcss_reg <= 8'd0;
      waddr_reg <= 7'd0;
      has_result <= 1'b0;
      result <= 8'd0;
      done <= 1'b0;
      for (i = 0; i < MAX_LEN; i = i + 1) begin
        max_count[i] <= 8'd0;
      end
    end else begin
      state <= state_next;
      rep <= rep_next;
      idx <= idx_next;
      pos <= pos_next;
      best <= best_next;
      lcss_reg <= lcss_next;
      waddr_reg <= waddr_next;
      has_result <= has_result_next;
      result <= (state_next == FINISH) ? best_next : result;
      done <= (state == FINISH);
      if (state_next == RUN && lcss_next != lcss_reg) begin
        max_count[waddr_next] <= lcss_next;
      end
    end
  end

  // Combinational next-state logic
  always_comb begin
    // Defaults (safe for all states)
    state_next = state;
    rep_next = rep;
    idx_next = idx;
    pos_next = pos;
    best_next = best;
    lcss_next = lcss_reg;
    waddr_next = waddr_reg;
    has_result_next = has_result;

    case (state)
      IDLE: begin
        rep_next = 4'd0;
        idx_next = 4'd0;
        pos_next = 7'd0;
        best_next = 8'd0;
        lcss_next = 8'd0;
        waddr_next = 7'd0;
        has_result_next = 1'b0;
        if (start) begin
          state_next = RUN;
        end
      end

      RUN: begin
        // 9-cycle per element FSM:
        // Cycle 0: sample current (rep, idx) -> latch cur_val
        // Cycles 1-7: scan previous max_count[0..pos-1] to compute cur_max_len (<= cur_val)
        // Cycle 8: compute lcss, update best, advance indices, set waddr
        // Then loop or finish.

        // Signals
        reg [3:0] n_reg, t_reg;
        reg [3:0] rep_lim;
        reg [8:0] cur_val;
        reg [7:0] cur_max_len;
        reg [6:0] pos_local;
        reg [7:0] best_local;
        reg [7:0] lcss_local;
        reg [6:0] waddr_local;
        reg [6:0] next_pos;
        reg [3:0] next_idx;
        reg [3:0] next_rep;
        reg [1:0] cycle;

        // Keep current context
        n_reg = n;
        t_reg = T;
        rep_lim = (t_reg < 4'd16) ? t_reg : 4'd16;
        pos_local = pos;
        best_local = best;
        lcss_local = lcss_reg;
        waddr_local = waddr_reg;
        cycle = pos_local[2:0]; // cycles 0..7 within each element

        // Cur element selection
        if (idx < n_reg) begin
          cur_val = a[idx];
        end else begin
          cur_val = 9'd0; // shouldn't happen if guards are correct
        end

        // Defaults for next
        next_pos = pos_local;
        next_idx = idx;
        next_rep = rep;
        cur_max_len = 8'd0;

        if (cycle == 3'd0) begin
          // Latch cur_val and initialize scanning window
          cur_max_len = 8'd0;
        end else begin
          // Scanning previous positions (0 .. pos_local-1) in 7 cycles
          // Determine previous position to inspect this cycle
          // Previous pos = pos_local - 1 - (8 - cycle)  => pos_local + cycle - 9
          // Only valid when >= 0 and < n_reg*rep + idx (i.e., already written)
          reg signed [7:0] p_idx;
          p_idx = $signed({1'b0, pos_local}) + $signed({1'b0, cycle}) - 8'd9;
          if (p_idx >= 0 && p_idx < pos_local) begin
            if (a[0] >= 0) begin // avoid tool complaints; condition is always true
              if (max_count[p_idx] > cur_max_len && max_count[p_idx] != 8'd0) begin
                // We need to check element ordering vs cur_val only for valid candidates.
                // The index p_idx corresponds to position in extended array: rep* n + idx_of_pos.
                // idx_of_pos = p_idx % n_reg; rep_of_pos = p_idx / n_reg
                reg [3:0] idx_of_pos, rep_of_pos;
                idx_of_pos = p_idx[2:0] % n_reg;        // p_idx is < 128, fits in 7 bits
                rep_of_pos = p_idx[2:0] / n_reg;
                // Compare actual array element at that position with cur_val
                // Non-decreasing: allowed if prev <= cur
                if (a[idx_of_pos] <= cur_val) begin
                  cur_max_len = max_count[p_idx];
                end
              end
            end
          end
        end

        if (cycle == 3'd7) begin
          // Finish computing for this element
          lcss_local = cur_max_len + 8'd1;
          if (lcss_local > best_local) best_local = lcss_local;
          waddr_local = pos_local;

          // Advance indices and position for next element
          if (idx == n_reg - 1) begin
            next_idx = 4'd0;
            if (rep == rep_lim - 1) begin
              // Last element processed -> finish next
              state_next = FINISH;
              has_result_next = 1'b1;
              next_pos = pos_local + 7'd1;
            end else begin
              next_rep = rep + 4'd1;
              next_pos = pos_local + 7'd1;
            end
          end else begin
            next_idx = idx + 4'd1;
            next_pos = pos_local + 7'd1;
          end
        end else begin
          // Keep scanning next cycle
          // No index/pos update yet
        end

        // Feed back
        lcss_next = lcss_local;
        best_next = best_local;
        waddr_next = waddr_local;
        rep_next = next_rep;
        idx_next = next_idx;
        pos_next = next_pos;
      end

      FINISH: begin
        // Hold result for exactly one cycle, then return to IDLE
        state_next = IDLE;
        rep_next = 4'd0;
        idx_next = 4'd0;
        pos_next = 7'd0;
        lcss_next = 8'd0;
        waddr_next = 7'd0;
        has_result_next = 1'b0;
        // best is already in result via sequential block on transition into FINISH
      end

      default: state_next = IDLE;
    endcase
  end

endmodule
