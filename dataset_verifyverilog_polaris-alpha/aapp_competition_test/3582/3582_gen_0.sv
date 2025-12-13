module mentor_assign(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] current_mentors [0:7],
  output reg [2:0] new_mentors [0:7],
  output reg done
);

  // State encoding
  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_INIT   = 3'd1,
    S_CHECK  = 3'd2,
    S_FIX    = 3'd3,
    S_VERIFY = 3'd4,
    S_DONE   = 3'd5
  } state_t;

  state_t state, next_state;

  // Internal storage of working assignments
  reg [2:0] assign_reg [0:7];

  // Counters and control
  reg [3:0] idx;             // up to 8
  reg [3:0] visited_count;
  reg [2:0] cur_node;
  reg [2:0] start_node;
  reg cycle_ok;

  // For FIX stage
  reg [2:0] fix_gaggler;     // current gaggler being fixed
  reg [2:0] candidate;       // candidate mentor
  reg checking_original;     // flag to try original first
  reg [7:0] used_mask;       // mentors already used in cycle

  // Visited flags for cycle check
  reg [7:0] visited;

  integer i;

  // Sequential state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      done <= 1'b0;
      cycle_ok <= 1'b0;
      idx <= 4'd0;
      visited_count <= 4'd0;
      cur_node <= 3'd0;
      start_node <= 3'd0;
      fix_gaggler <= 3'd0;
      candidate <= 3'd0;
      checking_original <= 1'b0;
      used_mask <= 8'd0;
      visited <= 8'd0;
      for (i = 0; i < 8; i = i + 1) begin
        assign_reg[i] <= 3'd0;
        new_mentors[i] <= 3'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Prepare for INIT
            idx <= 4'd0;
          end
        end

        S_INIT: begin
          // Copy current_mentors into assign_reg for i in [0, n-1]
          if (idx < n) begin
            assign_reg[idx] <= current_mentors[idx];
            idx <= idx + 1'b1;
          end
          // For i >= n, clear
          if (idx >= n && idx < 8) begin
            assign_reg[idx] <= 3'd0;
            idx <= idx + 1'b1;
          end
        end

        S_CHECK: begin
          // Implement multi-cycle check of single cycle covering 0..n-1
          // State sub-flow is controlled by idx, visited, etc.
          if (idx == 0) begin
            // Init check
            visited <= 8'd0;
            visited_count <= 4'd0;
            start_node <= 3'd0;
            cur_node <= 3'd0;
            idx <= 4'd1; // use idx as phase flag inside S_CHECK
            cycle_ok <= 1'b0;
          end else begin
            if (idx == 4'd1) begin
              // Start traversal from node 0
              if (cur_node >= n) begin
                cycle_ok <= 1'b0;
                idx <= 4'd15; // done
              end else if (visited[cur_node]) begin
                cycle_ok <= 1'b0;
                idx <= 4'd15;
              end else begin
                visited[cur_node] <= 1'b1;
                visited_count <= visited_count + 1'b1;
                cur_node <= assign_reg[cur_node];
                idx <= 4'd2;
              end
            end else if (idx == 4'd2) begin
              if (cur_node == start_node) begin
                // Ended a cycle
                if (visited_count == n) begin
                  cycle_ok <= 1'b1;
                end else begin
                  cycle_ok <= 1'b0;
                end
                idx <= 4'd15; // done
              end else if (cur_node >= n) begin
                cycle_ok <= 1'b0;
                idx <= 4'd15;
              end else if (visited[cur_node]) begin
                // hit visited before return to start
                cycle_ok <= 1'b0;
                idx <= 4'd15;
              end else begin
                visited[cur_node] <= 1'b1;
                visited_count <= visited_count + 1'b1;
                cur_node <= assign_reg[cur_node];
                // stay in phase 2
              end
            end
          end
        end

        S_FIX: begin
          // Construct a single cycle 0..n-1 respecting preferences
          // FIX runs as a small FSM using fix_gaggler, candidate, checking_original, used_mask
          if (idx == 0) begin
            // Initialization on entry
            used_mask <= 8'd0;
            fix_gaggler <= 3'd0;
            candidate <= 3'd0;
            checking_original <= 1'b1;
            idx <= 4'd1;
          end else begin
            if (fix_gaggler < n) begin
              if (checking_original) begin
                // Try original mentor if valid
                if (current_mentors[fix_gaggler] < n &&
                    !used_mask[current_mentors[fix_gaggler]] &&
                    current_mentors[fix_gaggler] != fix_gaggler) begin
                  assign_reg[fix_gaggler] <= current_mentors[fix_gaggler];
                  used_mask[current_mentors[fix_gaggler]] <= 1'b1;
                  fix_gaggler <= fix_gaggler + 1'b1;
                  checking_original <= 1'b1;
                  candidate <= 3'd0;
                end else begin
                  // Move to candidate search
                  checking_original <= 1'b0;
                  candidate <= 3'd0;
                end
              end else begin
                // Search lowest-numbered valid alternative mentor
                if (candidate < n) begin
                  if (!used_mask[candidate] && candidate != fix_gaggler) begin
                    assign_reg[fix_gaggler] <= candidate;
                    used_mask[candidate] <= 1'b1;
                    fix_gaggler <= fix_gaggler + 1'b1;
                    checking_original <= 1'b1;
                    candidate <= 3'd0;
                  end else begin
                    candidate <= candidate + 1'b1;
                  end
                end else begin
                  // Fallback (should not occur): force some assignment within n
                  assign_reg[fix_gaggler] <= (fix_gaggler + 3'd1) % n;
                  used_mask[(fix_gaggler + 3'd1) % n] <= 1'b1;
                  fix_gaggler <= fix_gaggler + 1'b1;
                  checking_original <= 1'b1;
                  candidate <= 3'd0;
                end
              end
            end
          end
        end

        S_VERIFY: begin
          // Reuse S_CHECK logic on assign_reg to ensure single cycle
          if (idx == 0) begin
            visited <= 8'd0;
            visited_count <= 4'd0;
            start_node <= 3'd0;
            cur_node <= 3'd0;
            idx <= 4'd1;
            cycle_ok <= 1'b0;
          end else begin
            if (idx == 4'd1) begin
              if (cur_node >= n) begin
                cycle_ok <= 1'b0;
                idx <= 4'd15;
              end else if (visited[cur_node]) begin
                cycle_ok <= 1'b0;
                idx <= 4'd15;
              end else begin
                visited[cur_node] <= 1'b1;
                visited_count <= visited_count + 1'b1;
                cur_node <= assign_reg[cur_node];
                idx <= 4'd2;
              end
            end else if (idx == 4'd2) begin
              if (cur_node == start_node) {
                if (visited_count == n) begin
                  cycle_ok <= 1'b1;
                end else begin
                  cycle_ok <= 1'b0;
                end
                idx <= 4'd15;
              end else if (cur_node >= n) begin
                cycle_ok <= 1'b0;
                idx <= 4'd15;
              end else if (visited[cur_node]) begin
                cycle_ok <= 1'b0;
                idx <= 4'd15;
              end else begin
                visited[cur_node] <= 1'b1;
                visited_count <= visited_count + 1'b1;
                cur_node <= assign_reg[cur_node];
              end
            end
          end
        end

        S_DONE: begin
          done <= 1'b1;
          // Drive outputs from assign_reg
          for (i = 0; i < 8; i = i + 1) begin
            if (i < n)
              new_mentors[i] <= assign_reg[i];
            else
              new_mentors[i] <= 3'd0;
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
        if (start)
          next_state = S_INIT;
      end

      S_INIT: begin
        if (idx == 8) // completed initialization/clearing
          next_state = S_CHECK;
      end

      S_CHECK: begin
        if (idx == 4'd15) begin
          if (cycle_ok)
            next_state = S_DONE;
          else begin
            next_state = S_FIX;
          end
        end
      end

      S_FIX: begin
        if (fix_gaggler >= n && idx != 0)
          next_state = S_VERIFY;
      end

      S_VERIFY: begin
        if (idx == 4'd15) begin
          next_state = S_DONE;
        end
      end

      S_DONE: begin
        if (!start)
          next_state = S_IDLE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule
