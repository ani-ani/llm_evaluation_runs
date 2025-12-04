module horse_chase(
  input clk,
  input rst_n,
  input start,
  input [3:0] L,
  input [3:0] A,
  input [3:0] B,
  input [3:0] P,
  output reg [4:0] time_out,
  output reg done
);

  // State encoding
  localparam IDLE     = 2'b00;
  localparam INIT     = 2'b01;
  localparam PROCESS  = 2'b10;
  localparam CAPTURED = 2'b11;

  reg [1:0] state, next_state;

  // Internal registers for positions
  reg [3:0] A_curr, B_curr, P_curr;

  // Start edge detection
  reg start_d;
  wire start_pulse;

  assign start_pulse = start & ~start_d;

  // Combinational wires for next positions
  reg [3:0] A_next, B_next, P_next;

  // Helper function: absolute difference (4-bit)
  function [3:0] abs_diff;
    input [3:0] x;
    input [3:0] y;
    begin
      if (x >= y)
        abs_diff = x - y;
      else
        abs_diff = y - x;
    end
  endfunction

  // Move cow 1m towards horse if distance > 1, else stay
  function [3:0] cow_move;
    input [3:0] cow_pos;
    input [3:0] horse_pos;
    reg [3:0] d;
    begin
      d = abs_diff(cow_pos, horse_pos);
      if (d > 4'd1) begin
        if (cow_pos < horse_pos)
          cow_move = cow_pos + 4'd1;
        else
          cow_move = cow_pos - 4'd1;
      end else begin
        cow_move = cow_pos; // stay
      end
    end
  endfunction

  // Compute metric: minimum distance to cows
  function [3:0] min_dist_to_cows;
    input [3:0] hp;
    input [3:0] a_pos;
    input [3:0] b_pos;
    reg [3:0] da, db;
    begin
      da = abs_diff(hp, a_pos);
      db = abs_diff(hp, b_pos);
      if (da <= db)
        min_dist_to_cows = da;
      else
        min_dist_to_cows = db;
    end
  endfunction

  // Horse optimal move (combinational)
  // Rules:
  // - Max step: 1m if horse currently on a cow, else 2m.
  // - Choose direction (left/right) and exact step (0..max_step) within [0,L]
  //   that maximizes min distance to cows after move.
  // - Deterministic tie-break: prefer larger min distance; if tie, prefer
  //   smaller displacement magnitude; if still tie, prefer left (negative).
  task automatic horse_optimal_move;
    input  [3:0] hp_in;
    input  [3:0] a_pos;
    input  [3:0] b_pos;
    input  [3:0] L_in;
    output [3:0] hp_out;
    reg [3:0] best_hp;
    reg [3:0] best_min_dist;
    reg [3:0] cand_hp;
    reg [3:0] cand_min_dist;
    integer step;
    integer dir; // -1, +1
    integer max_step;
    integer disp;
    integer best_disp;
    integer signed_cand_disp;
    begin
      // Determine max step based on whether horse is on a cow
      if ((hp_in == a_pos) || (hp_in == b_pos))
        max_step = 1;
      else
        max_step = 2;

      best_hp       = hp_in;
      best_min_dist = min_dist_to_cows(hp_in, a_pos, b_pos);
      best_disp     = 0;

      // Enumerate all candidate moves
      for (dir = -1; dir <= 1; dir = dir + 2) begin
        for (step = 0; step <= max_step; step = step + 1) begin
          signed_cand_disp = dir * step;
          cand_hp = hp_in; // default

          if (signed_cand_disp < 0) begin
            // Move left
            if (hp_in >= step)
              cand_hp = hp_in - step;
            else
              cand_hp = 0;
          end else begin
            // Move right or stay (dir=+1, step may be 0)
            if (hp_in + step <= L_in)
              cand_hp = hp_in + step;
            else
              cand_hp = L_in;
          end

          // Compute metric for candidate
          cand_min_dist = min_dist_to_cows(cand_hp, a_pos, b_pos);

          // Displacement magnitude from original hp
          if (cand_hp >= hp_in)
            disp = cand_hp - hp_in;
          else
            disp = hp_in - cand_hp;

          // Selection criteria
          if (cand_min_dist > best_min_dist) begin
            best_min_dist = cand_min_dist;
            best_hp       = cand_hp;
            best_disp     = disp;
          end else if (cand_min_dist == best_min_dist) begin
            if (disp < best_disp) begin
              best_hp   = cand_hp;
              best_disp = disp;
            end else if (disp == best_disp) begin
              // Tie: prefer left (smaller position) deterministically
              if (cand_hp < best_hp) begin
                best_hp = cand_hp;
              end
            end
          end
        end
      end

      hp_out = best_hp;
    end
  endtask

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      start_d   <= 1'b0;
      A_curr    <= 4'd0;
      B_curr    <= 4'd0;
      P_curr    <= 4'd0;
      time_out  <= 5'd0;
      done      <= 1'b0;
    end else begin
      start_d <= start;
      state   <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start_pulse) begin
            // Move to INIT in next_state; registers updated here
            A_curr   <= A;
            B_curr   <= B;
            P_curr   <= P;
            time_out <= 5'd0;
          end
        end

        INIT: begin
          // Positions already loaded; immediately go to PROCESS
          done <= 1'b0;
        end

        PROCESS: begin
          done <= 1'b0;
          // Update positions computed in combinational block
          A_curr   <= A_next;
          B_curr   <= B_next;
          P_curr   <= P_next;
          time_out <= time_out + 5'd1;
        end

        CAPTURED: begin
          // Hold outputs
          done <= 1'b1;
        end

        default: begin
          // Safety
          state <= IDLE;
        end
      endcase
    end
  end

  // Combinational next-state logic and position updates
  always @* begin
    next_state = state;

    // Default next positions equal current (overridden in PROCESS)
    A_next = A_curr;
    B_next = B_curr;
    P_next = P_curr;

    case (state)
      IDLE: begin
        if (start_pulse)
          next_state = INIT;
      end

      INIT: begin
        // Directly enter PROCESS on next cycle
        next_state = PROCESS;
      end

      PROCESS: begin
        // 1) Cows move towards current horse position
        A_next = cow_move(A_curr, P_curr);
        B_next = cow_move(B_curr, P_curr);

        // 2) Horse moves optimally based on new cow positions
        horse_optimal_move(P_curr, A_next, B_next, L, P_next);

        // 3) Check capture after horse moves
        if ((P_next == A_next) || (P_next == B_next)) begin
          next_state = CAPTURED;
        end else begin
          // Continue processing; termination bounded by problem constraints
          next_state = PROCESS;
        end
      end

      CAPTURED: begin
        // Wait for next start pulse to restart
        if (start_pulse)
          next_state = INIT;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule