module project_invites(
  input clk,
  input rst_n,
  input start,
  input [2:0] num_teams,
  input [7:0][4:0] teams_i,
  output reg [2:0] k,
  output reg [7:0][4:0] invitees,
  output reg done
);

  // Internal state encoding
  typedef enum logic [1:0] {
    S_IDLE  = 2'b00,
    S_LOAD  = 2'b01,
    S_PROC  = 2'b10,
    S_DONE  = 2'b11
  } state_t;

  state_t state, next_state;

  // Latched inputs
  reg [2:0] num_teams_r;
  reg [7:0][4:0] teams_r;

  // Per-team covered flag
  reg [7:0] covered;

  // Invitees list and count (internal wires/regs)
  reg [2:0] k_next;
  reg [7:0][4:0] invitees_next;

  // Iteration index
  reg [2:0] idx;
  reg [2:0] idx_next;

  // Combinational helper to check if an ID is already invited
  function automatic logic is_invited(
    input [4:0] id,
    input [7:0][4:0] inv_list,
    input [2:0]      inv_count
  );
    logic found;
    integer i;
    begin
      found = 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        if (i < inv_count && inv_list[i] == id)
          found = 1'b1;
      end
      is_invited = found;
    end
  endfunction

  // Combinational helper to compute how many uncovered teams contain candidate ID
  function automatic [3:0] cover_count(
    input [4:0] candidate,
    input [7:0][4:0] teams_loc,
    input [7:0]      covered_loc,
    input [2:0]      num_teams_loc
  );
    integer t;
    reg [3:0] count;
    begin
      count = 4'd0;
      for (t = 0; t < 8; t = t + 1) begin
        if ((t < num_teams_loc) && !covered_loc[t]) begin
          if (teams_loc[t] == candidate)
            count = count + 1'b1;
        end
      end
      cover_count = count;
    end
  endfunction

  // Combinational next-state logic and datapath updates
  always @* begin
    next_state     = state;
    k_next         = k;
    invitees_next  = invitees;
    idx_next       = idx;

    case (state)
      S_IDLE: begin
        if (start) begin
          next_state = S_LOAD;
        end
      end

      S_LOAD: begin
        // After latching in sequential block, initialize processing
        next_state    = S_PROC;
        idx_next      = 3'd0;
        k_next        = 3'd0;
        invitees_next = '{default:5'd0};
      end

      S_PROC: begin
        // Default: move to next index
        next_state = S_PROC;
        idx_next   = idx;

        // Check early termination: all teams covered or all processed
        if ((idx >= num_teams_r) || (&covered[7:0] || (covered[num_teams_r-1:0] == {num_teams_r{1'b1}}))) begin
          next_state = S_DONE;
        end else begin
          // Process current team if within num_teams_r
          if (idx < num_teams_r) begin
            if (!covered[idx]) begin
              // Consider candidates: ID1 and ID2 for this team
              // Note: teams_r holds single ID per entry per given interface typo; treat that ID as candidate
              // To align with problem statement (pairs), we assume even indices are ID1 and odd indices are ID2 of same team.
              // Team index idx corresponds to IDs at positions 2*idx and 2*idx+1 in teams_r.
              // Implemented carefully below.

              // Local copies
              reg [4:0] id1, id2;
              reg [3:0] c1, c2;
              reg       id1_inv, id2_inv;
              reg [4:0] chosen;

              id1 = teams_r[{idx,1'b0}];       // 2*idx
              id2 = teams_r[{idx,1'b1}];       // 2*idx+1

              // If already covered by existing invitees, just mark covered (no new invitee)
              id1_inv = is_invited(id1, invitees, k);
              id2_inv = is_invited(id2, invitees, k);

              if (id1_inv || id2_inv) begin
                // Covered by existing invitee, no change to invitees
                idx_next = idx + 3'd1;
              end else begin
                // Need to add one new invitee, choose best candidate
                c1 = cover_count(id1, teams_r, covered, num_teams_r);
                c2 = cover_count(id2, teams_r, covered, num_teams_r);

                // Choose candidate:
                // - Prefer higher cover count
                // - If tie, prefer friend (ID=9) if involved
                // - If still tie, choose id1
                if (c1 > c2) begin
                  chosen = id1;
                end else if (c2 > c1) begin
                  chosen = id2;
                end else begin
                  // c1 == c2
                  if (id1 == 5'd9 && id2 != 5'd9)
                    chosen = id1;
                  else if (id2 == 5'd9 && id1 != 5'd9)
                    chosen = id2;
                  else
                    chosen = id1; // deterministic
                end

                // Add chosen to invitees if not already present
                if (!is_invited(chosen, invitees, k) && (k < 3'd8)) begin
                  invitees_next[k] = chosen;
                  k_next           = k + 3'd1;
                end

                // Next team
                idx_next = idx + 3'd1;
              end
            end else begin
              // Team already covered, move on
              idx_next = idx + 3'd1;
            end

            // If we reached or passed num_teams_r after increment, go to DONE
            if (idx_next >= num_teams_r)
              next_state = S_DONE;
          end else begin
            next_state = S_DONE;
          end
        end
      end

      S_DONE: begin
        // Wait here until start deasserted then asserted again
        if (!start)
          next_state = S_IDLE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  // Sequential updates
  integer j;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      num_teams_r<= 3'd0;
      teams_r    <= '{default:5'd0};
      covered    <= 8'b0;
      k          <= 3'd0;
      invitees   <= '{default:5'd0};
      idx        <= 3'd0;
      done       <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            num_teams_r <= num_teams;
            teams_r     <= teams_i;
            covered     <= 8'b0;
            k           <= 3'd0;
            invitees    <= '{default:5'd0};
            idx         <= 3'd0;
          end
        end

        S_LOAD: begin
          // Initialize processing
          k        <= 3'd0;
          invitees <= '{default:5'd0};
          covered  <= 8'b0;
          idx      <= 3'd0;
          done     <= 1'b0;
        end

        S_PROC: begin
          // Apply next values
          k        <= k_next;
          invitees <= invitees_next;
          idx      <= idx_next;

          // Recompute covered map based on updated invitees (simple covering)
          // A team t is covered if any of its two IDs is in invitees.
          // Interpret teams_r as pairs (2*t, 2*t+1) for t < num_teams_r.
          for (j = 0; j < 8; j = j + 1) begin
            if (j < num_teams_r) begin
              if (is_invited(teams_r[{j,1'b0}], invitees_next, k_next) ||
                  is_invited(teams_r[{j,1'b1}], invitees_next, k_next)) begin
                covered[j] <= 1'b1;
              end else begin
                covered[j] <= covered[j];
              end
            end else begin
              covered[j] <= 1'b1; // outside num_teams treated as covered
            end
          end

          done <= 1'b0;
        end

        S_DONE: begin
          done <= 1'b1;
          // Hold k and invitees as already assigned
        end
      endcase
    end
  end

endmodule