module ivana_game(
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0] n,
  input  [9:0] nums [0:7],
  output reg [3:0] win_count,
  output reg done
);

  // Internal registers
  reg [2:0] n_reg;
  reg [9:0] nums_reg [0:7];

  // Per-start simulation state
  reg       active    [0:7];  // this start index valid (i < n)
  reg [2:0] len       [0:7];  // remaining length
  reg       turnA     [0:7];  // 1: Ivana's turn, 0: opponent's turn
  reg [3:0] scoreA    [0:7];  // Ivana odd count
  reg [3:0] scoreB    [0:7];  // Opponent odd count
  reg [2:0] L_idx     [0:7];  // left index (circular)
  reg [2:0] R_idx     [0:7];  // right index (circular)

  reg [4:0] cycle_cnt;        // up to 16 cycles
  reg       busy;

  integer i;

  // Helper function: compute best odd gain for Ivana
  function automatic [3:0] best_gainA;
    input [3:0] opt_left;
    input [3:0] opt_right;
    begin
      if (opt_left > opt_right) best_gainA = opt_left;
      else best_gainA = opt_right;
    end
  endfunction

  // Helper function: compute best odd gain for opponent (minimizing Ivana)
  function automatic [3:0] best_gainB;
    input [3:0] opt_left;
    input [3:0] opt_right;
    begin
      if (opt_left < opt_right) best_gainB = opt_left;
      else best_gainB = opt_right;
    end
  endfunction

  // Sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      win_count <= 4'd0;
      done      <= 1'b0;
      busy      <= 1'b0;
      cycle_cnt <= 5'd0;
      for (i = 0; i < 8; i = i + 1) begin
        active[i] <= 1'b0;
        len[i]    <= 3'd0;
        turnA[i]  <= 1'b0;
        scoreA[i] <= 4'd0;
        scoreB[i] <= 4'd0;
        L_idx[i]  <= 3'd0;
        R_idx[i]  <= 3'd0;
        nums_reg[i] <= 10'd0;
      end
      n_reg <= 3'd0;
    end else begin
      done <= 1'b0;

      if (start && !busy) begin
        // Latch inputs and initialize simulations
        n_reg <= (n == 3'd0) ? 3'd0 : n;
        for (i = 0; i < 8; i = i + 1) begin
          nums_reg[i] <= nums[i];
        end

        win_count <= 4'd0;
        cycle_cnt <= 5'd0;
        busy      <= 1'b1;

        for (i = 0; i < 8; i = i + 1) begin
          if (i < n) begin
            active[i] <= 1'b1;
            len[i]    <= n - 3'(i < n ? 0 : 0); // placeholder to avoid lint; overwritten below
          end else begin
            active[i] <= 1'b0;
            len[i]    <= 3'd0;
          end
          turnA[i]  <= 1'b1; // Ivana starts
          scoreA[i] <= 4'd0;
          scoreB[i] <= 4'd0;
          L_idx[i]  <= i[2:0];
          R_idx[i]  <= (i + n - 1) & 3'b111; // will refine below once n_reg set
        end

        // Correct per-start length/right index with n
        for (i = 0; i < 8; i = i + 1) begin
          if (i < n) begin
            len[i]   <= n;
            R_idx[i] <= (i + n - 1) & 3'b111;
          end
        end

      end else if (busy) begin
        // Perform one ply for all active starts in parallel
        reg [3:0] new_scoreA [0:7];
        reg [3:0] new_scoreB [0:7];
        reg [2:0] new_L      [0:7];
        reg [2:0] new_R      [0:7];
        reg [2:0] new_len    [0:7];
        reg       new_turnA  [0:7];
        reg       still_act  [0:7];

        // Default copy-through
        for (i = 0; i < 8; i = i + 1) begin
          new_scoreA[i] = scoreA[i];
          new_scoreB[i] = scoreB[i];
          new_L[i]      = L_idx[i];
          new_R[i]      = R_idx[i];
          new_len[i]    = len[i];
          new_turnA[i]  = turnA[i];
          still_act[i]  = active[i];
        end

        // Compute moves
        for (i = 0; i < 8; i = i + 1) begin
          if (active[i]) begin
            if (len[i] > 0) begin
              // Evaluate picking left or right end
              // Next Ivana odd counts assuming both parity outcomes reachable
              reg [3:0] iv_after_L;
              reg [3:0] iv_after_R;
              reg [3:0] op_after_L;
              reg [3:0] op_after_R;
              reg       choose_left;

              iv_after_L = scoreA[i];
              iv_after_R = scoreA[i];
              op_after_L = scoreB[i];
              op_after_R = scoreB[i];

              if (turnA[i]) begin
                // Ivana chooses to maximize her odd count
                if (nums_reg[L_idx[i]][0]) iv_after_L = scoreA[i] + 1'b1;
                if (nums_reg[R_idx[i]][0]) iv_after_R = scoreA[i] + 1'b1;

                // Optimal choice
                if (iv_after_L > iv_after_R) choose_left = 1'b1;
                else if (iv_after_R > iv_after_L) choose_left = 1'b0;
                else begin
                  // tie: choose left by convention
                  choose_left = 1'b1;
                end

                if (choose_left) begin
                  new_scoreA[i] = iv_after_L;
                  new_L[i]      = (L_idx[i] + 1) & 3'b111;
                end else begin
                  new_scoreA[i] = iv_after_R;
                  new_R[i]      = (R_idx[i] + 7) & 3'b111; // -1 mod 8
                end

              end else begin
                // Opponent chooses to minimize Ivana's odd count
                if (nums_reg[L_idx[i]][0]) iv_after_L = scoreA[i] + 1'b1;
                if (nums_reg[R_idx[i]][0]) iv_after_R = scoreA[i] + 1'b1;

                // Opponent is not scored; only Ivana's count matters
                if (iv_after_L < iv_after_R) choose_left = 1'b1;
                else if (iv_after_R < iv_after_L) choose_left = 1'b0;
                else begin
                  // tie: choose left by convention
                  choose_left = 1'b1;
                end

                if (choose_left) begin
                  new_scoreA[i] = iv_after_L;
                  new_L[i]      = (L_idx[i] + 1) & 3'b111;
                end else begin
                  new_scoreA[i] = iv_after_R;
                  new_R[i]      = (R_idx[i] + 7) & 3'b111;
                end
              end

              // Update length and turn
              new_len[i]   = len[i] - 1'b1;
              new_turnA[i] = ~turnA[i];

              if (new_len[i] == 3'd0) begin
                still_act[i] = 1'b0;
              end else begin
                still_act[i] = 1'b1;
              end

            end else begin
              still_act[i] = 1'b0;
            end
          end
        end

        // Commit state
        for (i = 0; i < 8; i = i + 1) begin
          scoreA[i] <= new_scoreA[i];
          scoreB[i] <= new_scoreB[i];
          L_idx[i]  <= new_L[i];
          R_idx[i]  <= new_R[i];
          len[i]    <= new_len[i];
          turnA[i]  <= new_turnA[i];
          active[i] <= still_act[i];
        end

        cycle_cnt <= cycle_cnt + 1'b1;

        // Check for completion: after all plies (max n <= 8) or cycle >= 16
        if (cycle_cnt >= 5'd15) begin
          // Force completion
          busy <= 1'b0;
          // Count winning starts (Ivana odd >= opponent odd)
          win_count <= 4'd0;
          for (i = 0; i < 8; i = i + 1) begin
            if (i < n_reg) begin
              if (scoreA[i] >= scoreB[i]) win_count <= win_count + 1'b1;
            end
          end
          done <= 1'b1;
        end else begin
          // Early completion if all done
          reg all_done;
          all_done = 1'b1;
          for (i = 0; i < 8; i = i + 1) begin
            if (i < n_reg && active[i]) all_done = 1'b0;
          end

          if (all_done && n_reg != 3'd0) begin
            busy <= 1'b0;
            win_count <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
              if (i < n_reg) begin
                if (scoreA[i] >= scoreB[i]) win_count <= win_count + 1'b1;
              end
            end
            done <= 1'b1;
          end
        end
      end
    end
  end

endmodule