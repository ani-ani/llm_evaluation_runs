module max_profit_calculator(
  input              clk,
  input              rst_n,
  input              start,
  input       [2:0]  num_candidates,
  input       [3:0]  l_i [0:7],
  input signed [15:0] s_i [0:7],
  input signed [15:0] c_v [0:15],
  output reg signed [31:0] max_profit,
  output reg         done
);

  // --------------------------------------------------------------------------
  // Parameters & localparams
  // --------------------------------------------------------------------------
  localparam int MAX_N      = 8;
  localparam int MAX_LVL    = 16; // aggressiveness levels index range 0..15
  localparam int MAX_CNT    = 8;  // max selected count (up to num_candidates)

  typedef enum logic [2:3] {
    ST_IDLE   = 3'd0,
    ST_INIT   = 3'd1,
    ST_LOAD   = 3'd2,
    ST_PROC   = 3'd3,
    ST_SWAP   = 3'd4,
    ST_SCAN   = 3'd5,
    ST_DONE   = 3'd6
  } state_t;

  state_t state, next_state;

  // DP tables: 3 banks (prev, curr, next), each 16 x 9 of 32-bit signed
  // Indexing: [level][count]
  reg signed [31:0] dp_prev   [0:MAX_LVL-1][0:MAX_CNT];
  reg signed [31:0] dp_curr   [0:MAX_LVL-1][0:MAX_CNT];
  reg signed [31:0] dp_next   [0:MAX_LVL-1][0:MAX_CNT];

  // Loop counters
  reg [3:0] init_lvl;      // 0..15
  reg [3:0] init_cnt;      // 0..8
  reg [2:0] cand_idx;      // 0..7 (processing index)
  reg [3:0] scan_lvl;      // 0..15
  reg [3:0] scan_cnt;      // 0..8

  // Latched inputs for current candidate
  reg [3:0]  cur_l;
  reg signed [15:0] cur_s;

  // Flags
  reg [2:0] n_cands;
  reg       init_done;
  reg       load_done;
  reg       proc_done;
  reg       swap_done;
  reg       scan_done;

  // --------------------------------------------------------------------------
  // Utility function: max of two signed 32-bit
  // --------------------------------------------------------------------------
  function automatic signed [31:0] fmax32(input signed [31:0] a, input signed [31:0] b);
    begin
      fmax32 = (a > b) ? a : b;
    end
  endfunction

  // --------------------------------------------------------------------------
  // State register
  // --------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= ST_IDLE;
    else
      state <= next_state;
  end

  // --------------------------------------------------------------------------
  // Next state logic
  // --------------------------------------------------------------------------
  always @* begin
    next_state = state;
    case (state)
      ST_IDLE: begin
        if (start)
          next_state = ST_INIT;
      end

      ST_INIT: begin
        if (init_done)
          next_state = ST_LOAD;
      end

      ST_LOAD: begin
        if (load_done)
          next_state = ST_PROC;
      end

      ST_PROC: begin
        if (proc_done)
          next_state = (cand_idx == 3'd0) ? ST_SCAN : ST_SWAP;
      end

      ST_SWAP: begin
        if (swap_done)
          next_state = ST_LOAD;
      end

      ST_SCAN: begin
        if (scan_done)
          next_state = ST_DONE;
      end

      ST_DONE: begin
        if (!start)
          next_state = ST_IDLE;
      end

      default: next_state = ST_IDLE;
    endcase
  end

  // --------------------------------------------------------------------------
  // Sequential logic
  // --------------------------------------------------------------------------
  integer i_lvl;
  integer i_cnt;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset outputs and control
      done        <= 1'b0;
      max_profit  <= 32'sd0;
      n_cands     <= 3'd0;
      init_lvl    <= 4'd0;
      init_cnt    <= 4'd0;
      cand_idx    <= 3'd0;
      scan_lvl    <= 4'd0;
      scan_cnt    <= 4'd0;
      init_done   <= 1'b0;
      load_done   <= 1'b0;
      proc_done   <= 1'b0;
      swap_done   <= 1'b0;
      scan_done   <= 1'b0;
      cur_l       <= 4'd0;
      cur_s       <= 16'sd0;

      // Initialize DP memories to very negative on reset
      for (i_lvl = 0; i_lvl < MAX_LVL; i_lvl = i_lvl + 1) begin
        for (i_cnt = 0; i_cnt <= MAX_CNT; i_cnt = i_cnt + 1) begin
          dp_prev[i_lvl][i_cnt] <= -32'sd2147483648;
          dp_curr[i_lvl][i_cnt] <= -32'sd2147483648;
          dp_next[i_lvl][i_cnt] <= -32'sd2147483648;
        end
      end
    end else begin
      // Default per-cycle flags
      init_done  <= 1'b0;
      load_done  <= 1'b0;
      proc_done  <= 1'b0;
      swap_done  <= 1'b0;
      scan_done  <= 1'b0;

      case (state)
        // ------------------------------------------------------
        // IDLE: wait for start
        // ------------------------------------------------------
        ST_IDLE: begin
          done       <= 1'b0;
          max_profit <= 32'sd0;
          if (start) begin
            n_cands  <= (num_candidates == 3'd0) ? 3'd1 : num_candidates;
            // prepare for init
            init_lvl <= 4'd0;
            init_cnt <= 4'd0;
          end
        end

        // ------------------------------------------------------
        // INIT: initialize DP base state
        // dp_prev: DP after processing zero candidates
        // DP[0][0] = 0, all others = -INF
        // ------------------------------------------------------
        ST_INIT: begin
          // Initialize all entries to -INF
          dp_prev[init_lvl][init_cnt] <= -32'sd2147483648;
          dp_curr[init_lvl][init_cnt] <= -32'sd2147483648;
          dp_next[init_lvl][init_cnt] <= -32'sd2147483648;

          if (init_cnt == MAX_CNT) begin
            init_cnt <= 4'd0;
            if (init_lvl == MAX_LVL-1) begin
              // Now set base condition
              dp_prev[0][0] <= 32'sd0;
              init_done <= 1'b1;
            end else begin
              init_lvl <= init_lvl + 4'd1;
            end
          end else begin
            init_cnt <= init_cnt + 4'd1;
          end

          if (init_done) begin
            // Setup first candidate index (reverse order)
            // last valid index = n_cands-1
            cand_idx <= (n_cands - 3'd1);
          end
        end

        // ------------------------------------------------------
        // LOAD: latch current candidate's parameters
        // ------------------------------------------------------
        ST_LOAD: begin
          cur_l <= l_i[cand_idx];
          cur_s <= s_i[cand_idx];

          // prepare processing counters
          scan_lvl <= 4'd0; // reuse as inner level counter for PROC
          scan_cnt <= 4'd0; // reuse as count counter for PROC
          load_done <= 1'b1;
        end

        // ------------------------------------------------------
        // PROC: compute dp_curr from dp_prev for this candidate
        // DP transition:
        //  - option 1: skip -> dp_curr[l][cnt] = max(dp_curr[l][cnt], dp_prev[l][cnt])
        //  - option 2: take candidate -> place at cur_l, merge while levels equal
        //    resulting level idx 'lvl2' and cost (cur_s + c_v[lvl2]) added
        // NOTES:
        //  - purely sequential over (level, count)
        // ------------------------------------------------------
        ST_PROC: begin
          // use scan_lvl (0..15) and scan_cnt (0..8) as nested loops
          // read previous value
          reg signed [31:0] prev_val;
          reg signed [31:0] best_val;
          reg signed [31:0] add_cost;
          reg [3:0] lvl2;
          reg [3:0] tmp_lvl;
          reg signed [31:0] skip_val;
          reg signed [31:0] take_val;

          prev_val = dp_prev[scan_lvl][scan_cnt];

          // start with skip option: carry forward previous DP
          skip_val = prev_val;
          best_val = skip_val;

          // take option: only if prev state is valid and we can increase count
          take_val = -32'sd2147483648;
          if ((prev_val != -32'sd2147483648) && (scan_cnt < MAX_CNT)) begin
            // simulate fight/merging when inserting new candidate
            // merging: if same level as inserted participant, level++ (bounded by 15)
            tmp_lvl = cur_l;
            if (tmp_lvl == scan_lvl) begin
              if (tmp_lvl < (MAX_LVL-1))
                tmp_lvl = tmp_lvl + 4'd1;
            end
            lvl2 = tmp_lvl;

            add_cost = {{16{cur_s[15]}}, cur_s} + {{16{c_v[lvl2][15]}}, c_v[lvl2]};
            take_val = prev_val + add_cost;

            best_val = fmax32(skip_val, take_val);
          end

          dp_curr[scan_lvl][scan_cnt] <= fmax32(dp_curr[scan_lvl][scan_cnt], best_val);

          // increment loop indices
          if (scan_cnt == MAX_CNT) begin
            scan_cnt <= 4'd0;
            if (scan_lvl == (MAX_LVL-1)) begin
              proc_done <= 1'b1;
            end else begin
              scan_lvl <= scan_lvl + 4'd1;
            end
          end else begin
            scan_cnt <= scan_cnt + 4'd1;
          end
        end

        // ------------------------------------------------------
        // SWAP: move dp_curr -> dp_prev for next candidate, clear dp_curr
        // ------------------------------------------------------
        ST_SWAP: begin
          // reuse init_lvl/init_cnt counters for swap/clear
          if (!swap_done) begin
            // perform one cell per cycle (still within latency budget)
            dp_prev[init_lvl][init_cnt] <= dp_curr[init_lvl][init_cnt];
            dp_curr[init_lvl][init_cnt] <= -32'sd2147483648;

            if (init_cnt == MAX_CNT) begin
              init_cnt <= 4'd0;
              if (init_lvl == (MAX_LVL-1)) begin
                swap_done <= 1'b1;
                init_lvl  <= 4'd0;
                // move to previous candidate index
                if (cand_idx != 3'd0)
                  cand_idx <= cand_idx - 3'd1;
              end else begin
                init_lvl <= init_lvl + 4'd1;
              end
            end else begin
              init_cnt <= init_cnt + 4'd1;
            end
          end
        end

        // ------------------------------------------------------
        // SCAN: after last candidate, scan dp_curr (or dp_prev) for max
        // We assume final DP resides in dp_curr when coming here.
        // If final came from dp_prev, ensure previous state machine path
        // leaves it in dp_curr; here we directly scan dp_curr.
        // ------------------------------------------------------
        ST_SCAN: begin
          // On entry from ST_PROC with cand_idx==0, dp_curr holds final DP.
          // We scan once for maximum across all levels and counts.
          if ((scan_lvl == 4'd0) && (scan_cnt == 4'd0)) begin
            max_profit <= -32'sd2147483648;
          end

          if (dp_curr[scan_lvl][scan_cnt] > max_profit)
            max_profit <= dp_curr[scan_lvl][scan_cnt];

          if (scan_cnt == MAX_CNT) begin
            scan_cnt <= 4'd0;
            if (scan_lvl == (MAX_LVL-1)) begin
              scan_done <= 1'b1;
            end else begin
              scan_lvl <= scan_lvl + 4'd1;
            end
          end else begin
            scan_cnt <= scan_cnt + 4'd1;
          end
        end

        // ------------------------------------------------------
        // DONE: hold result, assert done
        // ------------------------------------------------------
        ST_DONE: begin
          done <= 1'b1;
          // wait for start to be deasserted then reasserted to restart
        end

        default: ;
      endcase
    end
  end

endmodule