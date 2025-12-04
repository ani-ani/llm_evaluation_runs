module stone_game_winner(
  input  logic              clk,
  input  logic              rst_n,
  input  logic              start,
  input  logic       [3:0]  n,
  input  logic [7:0][15:0]  stones,
  output logic              outcome,
  output logic              done
);

  typedef enum logic [1:0] {
    IDLE        = 2'b00,
    PROCESSING  = 2'b01,
    DONE_STATE  = 2'b10
  } state_t;

  state_t               state, next_state;

  // Internal storage for stones
  logic [15:0]          arr [7:0];

  // Sorting control
  logic [5:0]           cycle_cnt;       // counts up to at least 39
  logic [3:0]           sort_i;          // outer loop index equivalent
  logic [3:0]           sort_j;          // inner loop index
  logic                 sorting_done;

  // Losing condition tracking
  logic                 lose_flag;
  logic [2:0]           dup_count;       // count duplicate pairs (max small)
  logic                 zero_more_than_one;
  logic                 bad_single_dup;

  // Parity / adjusted sum (only parity needed)
  logic                 adj_parity;      // 0: even, 1: odd

  // Latched inputs at start
  logic [3:0]           n_reg;

  // Combinational helpers
  logic                 do_compare_swap;
  logic [2:0]           j_next_idx;

  // FSM sequential
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      cycle_cnt   <= 6'd0;
      sort_i      <= 4'd0;
      sort_j      <= 4'd0;
      sorting_done<= 1'b0;
      lose_flag   <= 1'b0;
      dup_count   <= 3'd0;
      zero_more_than_one <= 1'b0;
      bad_single_dup <= 1'b0;
      adj_parity  <= 1'b0;
      n_reg       <= 4'd0;
      outcome     <= 1'b0;
      done        <= 1'b0;
      arr[0]      <= 16'd0;
      arr[1]      <= 16'd0;
      arr[2]      <= 16'd0;
      arr[3]      <= 16'd0;
      arr[4]      <= 16'd0;
      arr[5]      <= 16'd0;
      arr[6]      <= 16'd0;
      arr[7]      <= 16'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done        <= 1'b0;
          outcome     <= 1'b0;
          cycle_cnt   <= 6'd0;
          sorting_done<= 1'b0;
          sort_i      <= 4'd0;
          sort_j      <= 4'd0;
          lose_flag   <= 1'b0;
          dup_count   <= 3'd0;
          zero_more_than_one <= 1'b0;
          bad_single_dup <= 1'b0;
          adj_parity  <= 1'b0;

          if (start) begin
            // Latch inputs
            n_reg   <= (n > 4'd8) ? 4'd8 : n; // safety clamp
            arr[0]  <= stones[0];
            arr[1]  <= stones[1];
            arr[2]  <= stones[2];
            arr[3]  <= stones[3];
            arr[4]  <= stones[4];
            arr[5]  <= stones[5];
            arr[6]  <= stones[6];
            arr[7]  <= stones[7];
          end
        end

        PROCESSING: begin
          // Cycle counter for 40-cycle overall timing
          if (cycle_cnt < 6'd63)
            cycle_cnt <= cycle_cnt + 6'd1;

          // Single compare-swap step of bubble sort per cycle
          if (!sorting_done && (n_reg > 4'd1)) begin
            if (do_compare_swap) begin
              // swap arr[sort_j] and arr[sort_j+1]
              logic [15:0] tmp;
              tmp                 <= arr[sort_j];
              arr[sort_j]         <= arr[sort_j+1];
              arr[sort_j+1]       <= tmp;
            end

            // Advance indices (non-blocking, next cycle effective)
            if (sort_j + 1 >= (n_reg - sort_i - 1)) begin
              // end of inner pass
              sort_j <= 4'd0;
              if (sort_i + 1 >= (n_reg - 1)) begin
                sorting_done <= 1'b1;
              end else begin
                sort_i <= sort_i + 4'd1;
              end
            end else begin
              sort_j <= sort_j + 4'd1;
            end
          end else begin
            sorting_done <= sorting_done; // hold
          end

          // Once sorting_done, compute conditions and parity (one-time)
          if (sorting_done) begin
            // We'll compute only once: when lose_flag, dup_count, etc. are still at initial
            if (!lose_flag && dup_count == 3'd0 && !zero_more_than_one && !bad_single_dup && adj_parity == 1'b0) begin
              integer i;
              integer local_dup_cnt;
              integer zero_cnt;
              integer single_dup_idx;
              integer have_single_dup;
              integer conflict;
              integer val;
              integer adj_val;

              local_dup_cnt   = 0;
              zero_cnt        = 0;
              single_dup_idx  = -1;
              have_single_dup = 0;
              conflict        = 0;
              adj_val         = 0;

              // Count zeros and duplicates (within n_reg)
              for (i = 0; i < 8; i = i + 1) begin
                if (i < n_reg) begin
                  if (arr[i] == 16'd0) begin
                    zero_cnt = zero_cnt + 1;
                  end
                  if (i > 0 && arr[i] == arr[i-1]) begin
                    local_dup_cnt = local_dup_cnt + 1;
                    // track single duplicate index
                    if (have_single_dup == 0) begin
                      have_single_dup = 1;
                      single_dup_idx  = i;
                    end
                  end
                end
              end

              // Condition iii: more than one pile with 0 stones
              if (zero_cnt > 1)
                zero_more_than_one <= 1'b1;

              // Condition i: more than one duplicate pair exists
              if (local_dup_cnt > 1)
                dup_count <= local_dup_cnt[2:0];

              // Condition ii: exactly one duplicate where (duplicate_value - 1) is present
              if (local_dup_cnt == 1 && have_single_dup == 1) begin
                val = arr[single_dup_idx];
                // check if (val - 1) exists in array within n_reg
                if (val > 0) begin
                  for (i = 0; i < 8; i = i + 1) begin
                    if (i < n_reg && arr[i] == (val - 1)) begin
                      conflict = 1;
                    end
                  end
                end
                if (conflict == 1)
                  bad_single_dup <= 1'b1;
              end

              // Compute adjusted_sum parity if no losing flags by these raw counts
              // We use local flags to decide
              if (!( (local_dup_cnt > 1) || (zero_cnt > 1) || (local_dup_cnt == 1 && conflict == 1) )) begin
                for (i = 0; i < 8; i = i + 1) begin
                  if (i < n_reg) begin
                    adj_val = adj_val + (arr[i] - i);
                  end
                end
                adj_parity <= adj_val[0];
              end

              // Consolidate lose_flag
              if ((local_dup_cnt > 1) || (zero_cnt > 1) || (local_dup_cnt == 1 && conflict == 1)) begin
                lose_flag <= 1'b1;
              end
            end
          end

          // Transition to DONE behavior at fixed latency: done at 40th cycle after start
          // We rely on outer FSM next_state logic to enter DONE_STATE.
        end

        DONE_STATE: begin
          done    <= 1'b1;
          // outcome decided once when entering DONE_STATE via next_state logic.
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

  // Combinational: determine compare/swap action
  assign do_compare_swap = (state == PROCESSING) && !sorting_done && (n_reg > 1) &&
                           (sort_j + 1 < n_reg - sort_i) && (arr[sort_j] > arr[sort_j+1]);

  // Next state and outcome/done management
  always_comb begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start)
          next_state = PROCESSING;
      end

      PROCESSING: begin
        // Move to DONE_STATE exactly when 40 cycles have elapsed since PROCESSING start.
        // Assuming cycle_cnt starts from 0 at entry; we assert done when cycle_cnt == 6'd39.
        if (cycle_cnt == 6'd39) begin
          next_state = DONE_STATE;
        end
      end

      DONE_STATE: begin
        // Wait until start is deasserted and then asserted again (via IDLE)
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Outcome determination when entering DONE_STATE
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      outcome <= 1'b0;
    end else begin
      if (state == PROCESSING && next_state == DONE_STATE) begin
        // finalize outcome at transition to DONE_STATE
        if (lose_flag || (dup_count > 1) || zero_more_than_one || bad_single_dup)
          outcome <= 1'b0; // 'cslnb'
        else
          outcome <= adj_parity; // 1 => 'sjfnb', 0 => 'cslnb'
      end
    end
  end

endmodule