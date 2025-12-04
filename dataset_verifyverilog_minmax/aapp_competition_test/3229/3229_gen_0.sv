module worst_rank_calculator (
  input clk,
  input rst_n,
  input [3:0] num_contestants, // 2-4
  input [3:0] num_contests,     // 2-4
  input [6:0] scores [0:3][0:3], // 4x4 scores (7-bit each, 0-101)
  output reg [2:0] worst_rank,   // worst possible rank (3-bit)
  output reg done                // high when worst_rank is valid
);
  // Internal state
  localparam S_IDLE  = 3'b000;
  localparam S_LOAD  = 3'b001;
  localparam S_COMP  = 3'b010;
  localparam S_DONE  = 3'b011;
  localparam S_HOLD  = 3'b100;

  reg [2:0] state, next_state;
  reg [3:0] scnt;     // stabilization counter (1 cycle)
  reg [3:0] ccnt;     // compute cycle counter (up to 8 cycles)
  reg [3:0] prev_nc, prev_ncont, prev_ncontest; // to detect input changes
  reg [3:0] n_c;      // number of contestants (2-4)
  reg [3:0] n_cont;   // number of contests (2-4)
  reg [3:0] n_contest; // n_cont + 1

  // Pipelined data
  reg [6:0] s_reg [0:3][0:3];
  reg [8:0] top_reg [0:3];     // top-4 score sum per contestant (current)
  reg [8:0] final_reg [0:3];   // final aggregate with worst-case final contest

  // Sorting and ranking
  reg [3:0] order [0:3];       // contestant indices in descending final score order
  reg [3:0] order_next [0:3];  // next ordering
  reg [8:0] max_cur [0:3];     // current max score per contestant
  reg [8:0] max_cur_next [0:3];
  reg [8:0] final_next [0:3];

  // Combinational helpers
  integer i, j, k;

  // Control FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= S_IDLE;
      scnt      <= 4'b0;
      ccnt      <= 4'b0;
      prev_nc   <= 4'b0;
      prev_ncont<= 4'b0;
      prev_ncontest <= 4'b0;
      done      <= 1'b0;
    end else begin
      state <= next_state;
      if (state == S_IDLE) begin
        scnt <= 4'b1; // one-cycle stabilization
        ccnt <= 4'b0;
        prev_nc   <= n_c;
        prev_ncont<= n_cont;
        prev_ncontest <= n_contest;
        done <= 1'b0;
      end else if (state == S_LOAD) begin
        // load new stable data
        s_reg <= scores;
        n_c <= (num_contestants >= 4) ? 4 : ((num_contestants >= 2) ? num_contestants : 2);
        n_cont <= (num_contests >= 4) ? 4 : ((num_contests >= 2) ? num_contests : 2);
        n_contest <= n_cont + 1; // worst-case adds one final contest
        prev_nc   <= n_c;
        prev_ncont<= n_cont;
        prev_ncontest <= n_contest;
        ccnt <= 4'b0;
        done <= 1'b0;
      end else if (state == S_COMP) begin
        ccnt <= ccnt + 1;
        done <= 1'b0;
        // pipeline updates
        order <= order_next;
        max_cur <= max_cur_next;
        final_reg <= final_next;
      end else if (state == S_DONE) begin
        done <= 1'b1;
      end else if (state == S_HOLD) begin
        // wait for input changes
        done <= 1'b0;
      end
    end
  end

  // Next-state logic + compute pipeline
  always @(*) begin
    // defaults
    next_state = state;
    top_reg = 9'd0;
    final_next = final_reg;
    order_next = order;
    max_cur_next = max_cur;

    // Determine if inputs changed since last capture
    inputs_changed = (n_c != prev_nc) || (n_cont != prev_ncont) || (n_contest != prev_ncontest);

    case (state)
      S_IDLE: begin
        // one-cycle stabilization after reset deassertion
        if (scnt == 4'b1) begin
          next_state = S_LOAD;
          // capture current values
          n_c = (num_contestants >= 4) ? 4 : ((num_contestants >= 2) ? num_contestants : 2);
          n_cont = (num_contests >= 4) ? 4 : ((num_contests >= 2) ? num_contests : 2);
          n_contest = n_cont + 1;
          s_reg = scores;
        end
      end

      S_LOAD: begin
        // current aggregates: sum of top 4 scores (only n_cont valid columns used)
        for (i = 0; i < 4; i = i + 1) begin
          reg [8:0] sum;
          sum = 9'd0;
          for (j = 0; j < 4; j = j + 1) begin
            if (j < n_cont) begin
              sum = sum + s_reg[i][j];
            end
          end
          top_reg[i] = sum;
        end
        // Initialize sorting order and max_cur
        for (i = 0; i < 4; i = i + 1) begin
          order_next[i] = i[1:0];
          // compute current max score per contestant across first n_cont contests
          reg [6:0] mx;
          mx = 7'd0;
          for (j = 0; j < 4; j = j + 1) begin
            if (j < n_cont) begin
              if (s_reg[i][j] > mx) mx = s_reg[i][j];
            end
          end
          max_cur_next[i] = mx;
        end
        next_state = S_COMP;
        ccnt = 4'd0;
      end

      S_COMP: begin
        // Cycle 0: update order using current final_reg (from S_LOAD, zero), max_cur_next stable
        if (ccnt == 4'd0) begin
          // compute final aggregates for cycle 1 (recomputing now since final_reg not yet ready)
          for (i = 0; i < 4; i = i + 1) begin
            reg [8:0] mxcur;
            mxcur = max_cur[i];
            // worst-case: others get max(101, current max) on final contest
            if (i == 0) begin
              final_next[i] = top_reg[i] + 9'd0; // contestant 0 gets 0 in final
            end else begin
              final_next[i] = top_reg[i] + ((mxcur > 9'd101) ? mxcur : 9'd101);
            end
          end
          // sort others by final_next in descending order (stable by contestant id)
          for (i = 0; i < 4; i = i + 1) order_next[i] = order[i];
          // insertion sort descending by final score, stability by lower index first
          for (i = 1; i < 4; i = i + 1) begin
            reg [3:0] key_idx;
            reg [8:0] key_score;
            key_idx = order[i];
            key_score = final_next[key_idx];
            j = i;
            while ((j > 0) && (final_next[order[j-1]] < key_score)) begin
              order_next[j] = order[j-1];
              j = j - 1;
            end
            order_next[j] = key_idx;
          end
        end
        // Cycle 1: now final_reg is updated in S_COMP, recompute order for final_reg
        else if (ccnt == 4'd1) begin
          final_next = final_reg;
          for (i = 0; i < 4; i = i + 1) order_next[i] = order[i];
          for (i = 1; i < 4; i = i + 1) begin
            reg [3:0] key_idx;
            reg [8:0] key_score;
            key_idx = order[i];
            key_score = final_reg[key_idx];
            j = i;
            while ((j > 0) && (final_reg[order[j-1]] < key_score)) begin
              order_next[j] = order[j-1];
              j = j - 1;
            end
            order_next[j] = key_idx;
          end
        end

        // Compute worst rank for contestant 0 based on sorted order and ties
        if (ccnt >= 4'd1) begin
          reg [3:0] pos; // 0-based position of contestant 0 in sorted list
          reg [3:0] low_idx, high_idx;
          reg [8:0] c0_score;
          reg [3:0] n_c_reg;
          n_c_reg = n_c;
          c0_score = final_reg[0];
          pos = 4'd0;
          for (i = 0; i < 4; i = i + 1) begin
            if (order[i] == 0) begin
              pos = i;
              break;
            end
          end
          // find bounds of tie group
          low_idx = pos;
          while ((low_idx > 0) && (final_reg[order[low_idx-1]] == c0_score)) begin
            low_idx = low_idx - 1;
          end
          high_idx = pos;
          while ((high_idx < 3) && (final_reg[order[high_idx+1]] == c0_score)) begin
            high_idx = high_idx + 1;
          end
          // rounded-up average of positions (1-based) within tie group
          // rank = ceil((low+1 + high+1)/2)
          worst_rank = ((low_idx + high_idx + 3) >> 1); // (low+high+3)/2 rounded up via integer division
        end else begin
          worst_rank = 3'b0;
        end

        if (ccnt >= 4'd7) begin
          next_state = S_DONE;
        end else begin
          next_state = S_COMP;
        end
      end

      S_DONE: begin
        // Stay done until inputs change
        if (inputs_changed) begin
          next_state = S_LOAD;
        end else begin
          next_state = S_DONE;
        end
      end

      S_HOLD: begin
        // Unused; kept for extensibility
        next_state = inputs_changed ? S_LOAD : S_HOLD;
      end

      default: next_state = S_IDLE;
    endcase
  end

endmodule
