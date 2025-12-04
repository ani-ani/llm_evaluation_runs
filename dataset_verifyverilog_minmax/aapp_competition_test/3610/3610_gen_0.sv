module project_invites(
  input clk,
  input rst_n,
  input start,
  input [2:0] num_teams,
  input [7:0][4:0] teams_i,
  output reg [3:0] k,        // Changed to 4 bits to support up to 8 invitees
  output reg [7:0][4:0] invitees,
  output reg done
);

parameter ID_FRIEND = 5'd9;

typedef enum logic [1:0] {IDLE=2'b00, RUN=2'b01, DONE=2'b10} state_t;

state_t state, state_next;
logic [7:0] covered, covered_next;
logic [31:0] invited_mask, invited_mask_next;
logic [2:0] invite_idx, invite_idx_next;
logic [3:0] k, k_next;
logic [2:0] team_idx, team_idx_next;
logic done_next;

logic [7:0] mask, uncovered;
logic [31:0][7:0] membership;
logic [3:0] count[32];
logic [4:0] best_e;
logic [3:0] best_count;
logic [7:0][4:0] invitees_next;

always_comb begin
  // default assignments (hold current)
  state_next = state;
  covered_next = covered;
  invited_mask_next = invited_mask;
  invite_idx_next = invite_idx;
  k_next = k;
  team_idx_next = team_idx;
  done_next = done;
  invitees_next = invitees;

  // compute mask for valid teams
  mask = 8'b0;
  for (int i=0; i<8; i++) begin
    if (i < num_teams) mask[i] = 1'b1;
  end

  // compute uncovered
  uncovered = ~covered & mask;

  // compute membership for each employee (0-31) across all teams (0-7)
  for (int e=0; e<32; e++) begin
    for (int i=0; i<8; i++) begin
      logic [4:0] stockholm = teams_i[i];
      logic [4:0] london = {1'b1, stockholm[3:0]};
      membership[e][i] = (stockholm == e) || (london == e);
    end
  end

  // compute coverage count for each employee based on currently uncovered teams
  for (int e=0; e<32; e++) begin
    logic [7:0] v = membership[e] & uncovered;
    logic [3:0] pc = 0;
    for (int i=0; i<8; i++) begin
      pc = pc + v[i];
    end
    count[e] = pc;
  end

  // find best employee (max coverage, tie-break by friend ID=9)
  best_e = 0;
  best_count = 0;
  for (int e=0; e<32; e++) begin
    if (count[e] > best_count) begin
      best_count = count[e];
      best_e = e;
    end else if (count[e] == best_count) begin
      // prefer friend if equally optimal
      if (e == ID_FRIEND) begin
        best_e = e;
      end
    end
  end

  // state machine
  case (state)
    IDLE: begin
      if (start) begin
        // start new run: reset all state
        state_next = RUN;
        covered_next = 8'b0;
        invited_mask_next = 32'b0;
        invite_idx_next = 3'b0;
        k_next = 4'b0;
        team_idx_next = 3'b0;
        invitees_next = '0; // zero out invitees list
      end
    end

    RUN: begin
      // process current team index
      if (team_idx < num_teams) begin
        if (covered[team_idx] == 1'b0) begin
          // current team uncovered, add best employee
          if (!invited_mask[best_e]) begin
            // update coverage
            covered_next = covered | membership[best_e];
            invited_mask_next = invited_mask | (1 << best_e);
            // add to invitees list
            invitees_next = invitees; // copy current list
            invitees_next[invite_idx] = best_e[4:0];
            invite_idx_next = invite_idx + 1;
            k_next = k + 1;
          end else begin
            // best_e already invited (should not happen)
            covered_next = covered;
            invited_mask_next = invited_mask;
            invite_idx_next = invite_idx;
            k_next = k;
          end
        end else begin
          // team already covered, no new invitee
          covered_next = covered;
          invited_mask_next = invited_mask;
          invite_idx_next = invite_idx;
          k_next = k;
        end
        // move to next team
        team_idx_next = team_idx + 1;
      end else begin
        // no more teams (should not happen in RUN, but safe)
        team_idx_next = team_idx;
      end

      // check if we have processed all teams or all are covered
      if (team_idx_next == num_teams) begin
        state_next = DONE;
        done_next = 1'b1;
      end else if (covered_next == mask) begin
        // all teams covered, finish early
        state_next = DONE;
        done_next = 1'b1;
      end else begin
        state_next = RUN;
      end
    end

    DONE: begin
      done_next = 1'b1;
      if (!start) begin
        // return to idle when start is deasserted
        state_next = IDLE;
        done_next = 1'b0;
      end
    end
  endcase
end // always_comb

// sequential update
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    covered <= 8'b0;
    invited_mask <= 32'b0;
    invite_idx <= 3'b0;
    k <= 4'b0;
    team_idx <= 3'b0;
    done <= 1'b0;
    invitees <= '0;
  end else begin
    state <= state_next;
    covered <= covered_next;
    invited_mask <= invited_mask_next;
    invite_idx <= invite_idx_next;
    k <= k_next;
    team_idx <= team_idx_next;
    done <= done_next;
    invitees <= invitees_next;
  end
end

endmodule
