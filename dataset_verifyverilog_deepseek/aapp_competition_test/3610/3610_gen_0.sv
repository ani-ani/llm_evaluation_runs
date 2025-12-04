module project_invites(
  input clk,
  input rst_n,
  input start,
  input [2:0] num_teams,
  input [7:0][9:0] teams_i, // [team][9:0] = {ID2[4:0], ID1[4:0]}
  output reg [2:0] k,
  output reg [7:0][4:0] invitees,
  output reg done
);

typedef enum logic [1:0] {IDLE, PROCESS, DONE} state_t;
state_t state, next_state;

reg [7:0] covered_teams, covered_teams_next;
reg [7:0][4:0] invitees_next;
reg [2:0] k_next;
reg [2:0] cycle_count, cycle_count_next;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    covered_teams <= 8'h00;
    invitees <= {8{5'h00}};
    k <= 3'h0;
    cycle_count <= 3'h0;
    done <= 1'b0;
  end else begin
    state <= next_state;
    covered_teams <= covered_teams_next;
    invitees <= invitees_next;
    k <= k_next;
    cycle_count <= cycle_count_next;
    done <= (next_state == DONE);
  end
end

always_comb begin
  next_state = state;
  covered_teams_next = covered_teams;
  invitees_next = invitees;
  k_next = k;
  cycle_count_next = cycle_count;

  case (state)
    IDLE: begin
      if (start) begin
        next_state = PROCESS;
        covered_teams_next = 8'h00;
        invitees_next = {8{5'h00}};
        k_next = 3'h0;
        cycle_count_next = 3'h0;
      end
    end

    PROCESS: begin
      if (covered_teams == 8'hFF || cycle_count == 3'd7) begin
        next_state = DONE;
      end else begin
        automatic logic [3:0] count_array [32];
        for (int i=0; i<32; i++) count_array[i] = 4'h0;

        // Build coverage counts
        for (int t=0; t<8; t++) begin
          if (!covered_teams[t] && (t < num_teams)) begin
            automatic logic [4:0] id1 = teams_i[t][4:0];
            automatic logic [4:0] id2 = teams_i[t][9:5];
            count_array[id1]++;
            count_array[id2]++;
          end
        end

        // Find optimum employee
        automatic logic [3:0] max_count = 0;
        automatic logic [4:0] candidate = 5'h1F;
        for (int i=0; i<32; i++) begin
          if (count_array[i] > max_count || 
              (count_array[i] == max_count && (i == 9 || 
              (count_array[i] > 0 && candidate != 9 && i < candidate)))) begin
            max_count = count_array[i];
            candidate = (count_array[i] == 0) ? candidate : i[4:0];
          end
        end

        // Add candidate if new
        automatic logic exists = 1'b0;
        for (int i=0; i<8; i++) begin
          if (invitees[i] == candidate) exists = 1'b1;
        end

        if (!exists && max_count > 0 && k < 3'd8) begin
          invitees_next[k] = candidate;
          k_next = k + 1;
        end

        // Update coverage
        for (int t=0; t<8; t++) begin
          if (!covered_teams_next[t] && (t < num_teams) && 
             (teams_i[t][4:0] == candidate || teams_i[t][9:5] == candidate)) begin
            covered_teams_next[t] = 1'b1;
          end
        end

        cycle_count_next = cycle_count + 1;
        next_state = (covered_teams_next == 8'hFF) ? DONE : PROCESS;
      end
    end

    DONE: begin
      next_state = IDLE;
    end

    default: next_state = IDLE;
  endcase
end

endmodule