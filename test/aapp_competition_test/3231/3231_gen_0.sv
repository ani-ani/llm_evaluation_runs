module friendship_validator(
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0] n,
  input  [3:0] p,
  input  [3:0] q,
  input  [7:0] friends [0:7],
  output reg decision,
  output reg done
);

  // Internal registers
  reg [7:0] valid_mask;          // mask for existing students [0..n-1]
  reg [2:0] i_idx;               // loop index for symmetry check and timing
  reg [2:0] j_idx;               // inner index
  reg       running;             // indicates active processing
  reg       sym_fail;            // symmetry check failed
  reg       part_ok;             // partition existence flag
  reg [3:0] group_count;         // number of groups created
  reg [7:0] group_mask [0:7];    // group bitmasks (max 8 groups for n<=8)
  reg [2:0] student_gidx [0:7];  // group index per student
  reg [3:0] group_size [0:7];    // size per group
  reg [3:0] group_ext [0:7];     // external edges per group

  // FSM states
  localparam S_IDLE       = 3'd0;
  localparam S_INIT       = 3'd1;
  localparam S_SYM_CHECK  = 3'd2;
  localparam S_BUILD_G    = 3'd3;
  localparam S_EVAL_GROUP = 3'd4;
  localparam S_DONE       = 3'd5;

  reg [2:0] state, next_state;

  // Utility: count bits in 8-bit value
  function automatic [3:0] popcount8(input [7:0] v);
    integer k;
    reg [3:0] c;
    begin
      c = 4'd0;
      for (k = 0; k < 8; k = k + 1) begin
        c = c + v[k];
      end
      popcount8 = c;
    end
  endfunction

  // Combinational next-state logic
  always @* begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end

      S_INIT: begin
        next_state = S_SYM_CHECK;
      end

      S_SYM_CHECK: begin
        // advance until all pairs (i<j) checked or error
        if (sym_fail)
          next_state = S_DONE;
        else if (i_idx == (n[2:0]-1) && j_idx == (n[2:0]-1))
          next_state = S_BUILD_G;
      end

      S_BUILD_G: begin
        // After building partition for all students, go to group evaluation
        if (i_idx == (n[2:0]))
          next_state = S_EVAL_GROUP;
      end

      S_EVAL_GROUP: begin
        // After evaluating all groups, go done
        if (i_idx == group_count[2:0])
          next_state = S_DONE;
      end

      S_DONE: begin
        if (!start)
          next_state = S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  integer gi, sj;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      running    <= 1'b0;
      decision   <= 1'b0;
      done       <= 1'b0;
      sym_fail   <= 1'b0;
      part_ok    <= 1'b0;
      valid_mask <= 8'd0;
      i_idx      <= 3'd0;
      j_idx      <= 3'd0;
      group_count <= 4'd0;
      for (gi = 0; gi < 8; gi = gi + 1) begin
        group_mask[gi]  <= 8'd0;
        group_size[gi]  <= 4'd0;
        group_ext[gi]   <= 4'd0;
        student_gidx[gi]<= 3'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done     <= 1'b0;
          decision <= 1'b0;
          sym_fail <= 1'b0;
          part_ok  <= 1'b0;
          running  <= 1'b0;
          if (start) begin
            // prepare valid mask and counters
            valid_mask <= (n == 0) ? 8'd0 : ((8'hFF >> (8 - n[2:0])));
          end
        end

        S_INIT: begin
          running    <= 1'b1;
          done       <= 1'b0;
          decision   <= 1'b0;
          sym_fail   <= 1'b0;
          part_ok    <= 1'b0;
          // init indices for symmetry check (start at i=0,j=1 if n>1)
          i_idx      <= 3'd0;
          j_idx      <= (n > 1) ? 3'd1 : 3'd0;
          // clear group structures
          group_count <= 4'd0;
          for (gi = 0; gi < 8; gi = gi + 1) begin
            group_mask[gi]   <= 8'd0;
            group_size[gi]   <= 4'd0;
            group_ext[gi]    <= 4'd0;
            student_gidx[gi] <= 3'd0;
          end
        end

        S_SYM_CHECK: begin
          if (!sym_fail && n > 1) begin
            // Check symmetry for pair (i_idx, j_idx) when i<j<n
            if (i_idx < j_idx && j_idx < n[2:0]) begin
              if (friends[i_idx][j_idx] !== friends[j_idx][i_idx]) begin
                sym_fail <= 1'b1;
              end
            end

            // advance indices over all pairs (i<j<n)
            if (!sym_fail) begin
              if (j_idx + 1 < n[2:0]) begin
                j_idx <= j_idx + 1'b1;
              end else begin
                if (i_idx + 2 < n[2:0]) begin
                  i_idx <= i_idx + 1'b1;
                  j_idx <= i_idx + 2; // next j = i+2 to keep i<j
                end else begin
                  // finish when i reaches n-2, j scans to n-1
                  i_idx <= n[2:0]-1;
                  j_idx <= n[2:0]-1;
                end
              end
            end
          end
        end

        S_BUILD_G: begin
          // Greedy grouping: each student joins first existing group
          // that has size <= p and where all members are mutual friends;
          // otherwise start a new group.

          if (i_idx < n[2:0]) begin
            // decide group for student i_idx
            reg [2:0] chosen_g;
            reg       placed;
            reg [7:0] cmask;
            reg [7:0] fm;
            chosen_g = 3'd0;
            placed   = 1'b0;
            fm       = friends[i_idx] & valid_mask; // consider only valid students

            // try to fit in existing groups
            for (gi = 0; gi < 8; gi = gi + 1) begin
              if (!placed && gi < group_count) begin
                if (group_size[gi] < p) begin
                  cmask = group_mask[gi];
                  // require i is friends with all in group: for every bit set in cmask, fm must also have 1
                  if ((cmask & ~fm) == 8'd0) begin
                    chosen_g = gi[2:0];
                    placed   = 1'b1;
                  end
                end
              end
            end

            // if not placed, start a new group (if capacity)
            if (!placed) begin
              if (group_count < 8) begin
                chosen_g = group_count[2:0];
                group_count <= group_count + 1'b1;
                group_mask[chosen_g] <= 8'd0; // will set below
                group_size[chosen_g] <= 4'd0;
              end
              placed = 1'b1; // assume always possible since n<=8, p>=1 implied by constraints
            end

            // assign student i to chosen group
            student_gidx[i_idx]          <= chosen_g;
            group_mask[chosen_g]         <= group_mask[chosen_g] | (8'b1 << i_idx);
            group_size[chosen_g]         <= group_size[chosen_g] + 1'b1;

            // move to next student
            i_idx <= i_idx + 1'b1;
          end
          else begin
            // all students assigned; ensure group_count is consistent
            if (group_count == 0 && n != 0)
              group_count <= 1; // in case all went into implicit group 0
            // prepare for evaluation
            i_idx <= 3'd0;
          end
        end

        S_EVAL_GROUP: begin
          // For each group, compute external edges and check constraints
          if (i_idx < group_count[2:0]) begin
            reg [7:0] gm;
            reg [7:0] ext_mask;
            reg [7:0] fm;
            reg [3:0] ext_cnt;

            gm       = group_mask[i_idx];
            ext_cnt  = 4'd0;

            // sum external edges: for each member s in group, count friends outside group
            for (sj = 0; sj < 8; sj = sj + 1) begin
              if (gm[sj]) begin
                fm       = friends[sj] & valid_mask;
                ext_mask = fm & ~gm; // friends outside this group
                ext_cnt  = ext_cnt + popcount8(ext_mask);
              end
            end

            group_ext[i_idx] <= ext_cnt;

            // check this group's size and external edges
            if (group_size[i_idx] > p || ext_cnt > q)
              part_ok <= 1'b0;

            // if first group, initialize part_ok to true then AND
            if (i_idx == 3'd0) begin
              if (group_size[i_idx] <= p && ext_cnt <= q)
                part_ok <= 1'b1;
              else
                part_ok <= 1'b0;
            end else begin
              if (!(group_size[i_idx] <= p && ext_cnt <= q))
                part_ok <= 1'b0;
            end

            i_idx <= i_idx + 1'b1;
          end
        end

        S_DONE: begin
          // decision: 1 = detection required (no valid partition), 0 = valid partition exists
          // If symmetry failed -> invalid -> decision=1.
          // Else if at least one partition (our greedy attempt) meets constraints -> decision=0.
          // Otherwise decision=1.
          done <= 1'b1;
          if (sym_fail)
            decision <= 1'b1;
          else if (part_ok)
            decision <= 1'b0;
          else
            decision <= 1'b1;
        end

        default: ;
      endcase
    end
  end

endmodule