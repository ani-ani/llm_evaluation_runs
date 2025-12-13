module zerg_rush_simulator(
  input clk,
  input rst_n,
  input start,
  input [1:0] p1_attack_upgrade,
  input [1:0] p1_armor_upgrade,
  input [1:0] p2_attack_upgrade,
  input [1:0] p2_armor_upgrade,
  input [7:0] init_grid,
  input [1:0] turns,
  output reg [7:0] final_grid,
  output reg done
);

  // State encoding
  localparam IDLE           = 3'd0;
  localparam COMPUTE_ATTACK = 3'd1;
  localparam APPLY_ATTACK   = 3'd2;
  localparam COMPUTE_MOVE   = 3'd3;
  localparam APPLY_MOVE     = 3'd4;
  localparam REGEN          = 3'd5;
  localparam DONE           = 3'd6;

  reg [2:0] state, next_state;

  // Turn and cycle tracking
  reg [2:0] cur_turn;           // enough for 0-7, we only need up to 3
  reg [2:0] target_turns;       // latched from input

  // Grid representation:
  // Each cell: [7:6] owner (00 empty, 01 p1, 10 p2), [5:0] HP (0-63)
  reg [7:0] cell00, cell01, cell10, cell11;          // current grid
  reg [7:0] next_cell00, next_cell01, next_cell10, next_cell11; // next grid

  // Attack damage accumulators per cell
  reg [6:0] dmg00, dmg01, dmg10, dmg11; // up to multiple hits, 7 bits safe

  // Movement intention: from each source cell -> dest coordinates
  // dest: 2-bit encoding: 2'b00: (0,0), 01: (0,1), 10: (1,0), 11: (1,1), or 2'bxx invalid
  reg [1:0] mv_src00_dest;
  reg [1:0] mv_src01_dest;
  reg [1:0] mv_src10_dest;
  reg [1:0] mv_src11_dest;

  // Latched upgrades
  reg [1:0] p1_atk_u, p1_arm_u, p2_atk_u, p2_arm_u;

  // Helper functions
  function automatic [1:0] owner(input [7:0] c);
    owner = c[7:6];
  endfunction

  function automatic [5:0] hp(input [7:0] c);
    hp = c[5:0];
  endfunction

  function automatic [7:0] make_cell(input [1:0] own, input [5:0] h);
    make_cell = {own,h};
  endfunction

  function automatic [5:0] clamp_hp(input integer v);
    if (v <= 0) clamp_hp = 6'd0;
    else if (v > 63) clamp_hp = 6'd63;
    else clamp_hp = v[5:0];
  endfunction

  // Compute damage per attack
  function automatic [3:0] compute_damage(
    input [1:0] atk_owner,
    input [1:0] def_owner,
    input [1:0] p1_atk,
    input [1:0] p1_arm,
    input [1:0] p2_atk,
    input [1:0] p2_arm
  );
    integer base, bonus_atk, bonus_arm, d;
    begin
      base = 5;
      if (atk_owner == 2'b01) begin
        bonus_atk = p1_atk;
      end else begin
        bonus_atk = p2_atk;
      end
      if (def_owner == 2'b01) begin
        bonus_arm = p1_arm;
      end else begin
        bonus_arm = p2_arm;
      end
      d = base + bonus_atk - bonus_arm;
      if (d < 1) d = 1;
      if (d > 15) d = 15; // 4 bits
      compute_damage = d[3:0];
    end
  endfunction

  // Manhattan distance on 2x2
  function automatic [2:0] manhattan(
    input [0:0] sr,
    input [0:0] sc,
    input [0:0] tr,
    input [0:0] tc
  );
    reg [2:0] d;
    begin
      d = 0;
      if (sr != tr) d = d + 1;
      if (sc != tc) d = d + 1;
      manhattan = d;
    end
  endfunction

  // Determine if any enemy adjacent (8 dirs, bounded grid)
  function automatic has_adj_enemy(
    input [7:0] c,
    input [7:0] n0,
    input [7:0] n1,
    input [7:0] n2,
    input [7:0] n3,
    input [7:0] n4,
    input [7:0] n5,
    input [7:0] n6,
    input [7:0] n7
  );
    reg [1:0] o;
    begin
      o = owner(c);
      if (o == 2'b00) begin
        has_adj_enemy = 1'b0;
      end else begin
        has_adj_enemy =
          ((owner(n0) != 2'b00) && (owner(n0) != o)) ||
          ((owner(n1) != 2'b00) && (owner(n1) != o)) ||
          ((owner(n2) != 2'b00) && (owner(n2) != o)) ||
          ((owner(n3) != 2'b00) && (owner(n3) != o)) ||
          ((owner(n4) != 2'b00) && (owner(n4) != o)) ||
          ((owner(n5) != 2'b00) && (owner(n5) != o)) ||
          ((owner(n6) != 2'b00) && (owner(n6) != o)) ||
          ((owner(n7) != 2'b00) && (owner(n7) != o));
      end
    end
  endfunction

  // Compute best movement destination for a given cell position and owner.
  // Directions tie-break: north > northeast > east > southeast > south > southwest > west > northwest (as given).
  // Movement conflicts resolved later by destination priority (northernmost then westernmost).
  function automatic [1:0] choose_move_dest(
    input [0:0] sr,
    input [0:0] sc,
    input [1:0] own,
    input [7:0] c00,
    input [7:0] c01,
    input [7:0] c10,
    input [7:0] c11
  );
    integer best_dist;
    reg has_enemy;
    reg [0:0] er, ec;
    reg [1:0] dest;
    integer d;
    begin
      // Find nearest enemy cell by Manhattan distance.
      has_enemy = 0;
      best_dist = 7; // larger than max on 2x2
      dest = {sr,sc};

      // (0,0)
      if (owner(c00) != 2'b00 && owner(c00) != own) begin
        d = manhattan(sr,sc,1'b0,1'b0);
        if (!has_enemy || d < best_dist) begin
          has_enemy = 1;
          best_dist = d;
          er = 1'b0; ec = 1'b0;
        end
      end
      // (0,1)
      if (owner(c01) != 2'b00 && owner(c01) != own) begin
        d = manhattan(sr,sc,1'b0,1'b1);
        if (!has_enemy || d < best_dist) begin
          has_enemy = 1;
          best_dist = d;
          er = 1'b0; ec = 1'b1;
        end
      end
      // (1,0)
      if (owner(c10) != 2'b00 && owner(c10) != own) begin
        d = manhattan(sr,sc,1'b1,1'b0);
        if (!has_enemy || d < best_dist) begin
          has_enemy = 1;
          best_dist = d;
          er = 1'b1; ec = 1'b0;
        end
      end
      // (1,1)
      if (owner(c11) != 2'b00 && owner(c11) != own) begin
        d = manhattan(sr,sc,1'b1,1'b1);
        if (!has_enemy || d < best_dist) begin
          has_enemy = 1;
          best_dist = d;
          er = 1'b1; ec = 1'b1;
        end
      end

      if (!has_enemy || best_dist == 0) begin
        // No enemy or already at enemy cell: no move
        choose_move_dest = {sr,sc};
      end else begin
        // Move one step towards (er,ec) using direction priority.
        // We encode candidate moves in priority order.
        // north
        if (sr > er && sr > 0) begin
          dest = {sr-1'b1, sc};
        end
        // northeast
        else if (sr > er && sr > 0 && sc < ec && sc < 1) begin
          dest = {sr-1'b1, sc+1'b1};
        end
        // east
        else if (sc < ec && sc < 1) begin
          dest = {sr, sc+1'b1};
        end
        // southeast
        else if (sr < er && sr < 1 && sc < ec && sc < 1) begin
          dest = {sr+1'b1, sc+1'b1};
        end
        // south
        else if (sr < er && sr < 1) begin
          dest = {sr+1'b1, sc};
        end
        // southwest
        else if (sr < er && sr < 1 && sc > ec && sc > 0) begin
          dest = {sr+1'b1, sc-1'b1};
        end
        // west
        else if (sc > ec && sc > 0) begin
          dest = {sr, sc-1'b1};
        end
        // northwest
        else if (sr > er && sr > 0 && sc > ec && sc > 0) begin
          dest = {sr-1'b1, sc-1'b1};
        end
        else begin
          dest = {sr,sc};
        end
        choose_move_dest = dest;
      end
    end
  endfunction

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = COMPUTE_ATTACK;
      end
      COMPUTE_ATTACK: begin
        next_state = APPLY_ATTACK;
      end
      APPLY_ATTACK: begin
        next_state = COMPUTE_MOVE;
      end
      COMPUTE_MOVE: begin
        next_state = APPLY_MOVE;
      end
      APPLY_MOVE: begin
        next_state = REGEN;
      end
      REGEN: begin
        // After regen, either next turn or done
        if (cur_turn + 1 < target_turns)
          next_state = COMPUTE_ATTACK;
        else
          next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cur_turn <= 3'd0;
      target_turns <= 3'd0;
      cell00 <= 8'd0;
      cell01 <= 8'd0;
      cell10 <= 8'd0;
      cell11 <= 8'd0;
      final_grid <= 8'd0;
      done <= 1'b0;
      p1_atk_u <= 2'd0;
      p1_arm_u <= 2'd0;
      p2_atk_u <= 2'd0;
      p2_arm_u <= 2'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Latch inputs and initialize grid from init_grid
            // Interpretation: 2 bits per cell: [r0c0, r0c1, r1c0, r1c1], HP default 35 if occupied.
            p1_atk_u <= p1_attack_upgrade;
            p1_arm_u <= p1_armor_upgrade;
            p2_atk_u <= p2_attack_upgrade;
            p2_arm_u <= p2_armor_upgrade;
            target_turns <= {1'b0,turns};
            cur_turn <= 3'd0;

            // Decode owners from init_grid
            // [7:6]=r0c0, [5:4]=r0c1, [3:2]=r1c0, [1:0]=r1c1
            cell00 <= (init_grid[7:6] == 2'b00) ? 8'd0 : {init_grid[7:6], 6'd35};
            cell01 <= (init_grid[5:4] == 2'b00) ? 8'd0 : {init_grid[5:4], 6'd35};
            cell10 <= (init_grid[3:2] == 2'b00) ? 8'd0 : {init_grid[3:2], 6'd35};
            cell11 <= (init_grid[1:0] == 2'b00) ? 8'd0 : {init_grid[1:0], 6'd35};
          end
        end

        COMPUTE_ATTACK: begin
          // Initialize damage accumulators
          dmg00 <= 7'd0;
          dmg01 <= 7'd0;
          dmg10 <= 7'd0;
          dmg11 <= 7'd0;

          // For each attacker cell, check 8 neighbors and accumulate damage on enemy targets.
          // Grid indices: (0,0)=cell00, (0,1)=cell01, (1,0)=cell10, (1,1)=cell11

          // Helper variables
          // We'll unroll logic explicitly.

          // Attacker at (0,0)
          if (owner(cell00) != 2'b00) begin
            // neighbors within bounds: (0,1),(1,0),(1,1)
            if (owner(cell01) != 2'b00 && owner(cell01) != owner(cell00)) begin
              dmg01 <= dmg01 + compute_damage(owner(cell00), owner(cell01), p1_atk_u, p1_arm_u, p2_atk_u, p2_arm_u);
            end
            if (owner(cell10) != 2'b00 && owner(cell10) != owner(cell00)) begin
              dmg10 <= dmg10 + compute_damage(owner(cell00), owner(cell10), p1_atk_u, p1_arm_u, p2_atk_u, p2_arm_u);
            end
            if (owner(cell11) != 2'b00 && owner(cell11) != owner(cell00)) begin
              dmg11 <= dmg11 + compute_damage(owner(cell00), owner(cell11), p1_atk_u, p1_arm_u, p2_atk_u, p2_arm_u);
            end
          end

          // Attacker at (0,1)
          if (owner(cell01) != 2'b00) begin
            // neighbors: (0,0),(1,0),(1,1)
            if (owner(cell00) != 2'b00 && owner(cell00) != owner(cell01)) begin
              dmg00 <= dmg00 + compute_damage(owner(cell01), owner(cell00), p1_atk_u, p1_arm_u, p2_atk_u, p2_arm_u);
            end
            if (owner(cell10) != 2'b00 && owner(cell10) != owner(cell01)) begin
              dmg10 <= dmg10 + compute_damage(owner(cell01), owner(cell10), p1_atk_u, p1_arm_u, p2_atk_u, p2_arm_u);
            end
            if (owner(cell11) != 2'b00 && owner(cell11) != owner(cell01)) begin
              dmg11 <= dmg11 + compute_damage(owner(cell01), owner(cell11), p1_atk_u, p1_arm_u, p2_atk_u, p2_arm_u);
            end
          end

          // Attacker at (1,0)
          if (owner(cell10) != 2'b00) begin
            // neighbors: (0,0),(0,1),(1,1)
            if (owner(cell00) != 2'b00 && owner(cell00) != owner(cell10)) begin
              dmg00 <= dmg00 + compute_damage(owner(cell10), owner(cell00), p1_atk_u, p1_arm_u, p2_atk_u, p2_arm_u);
            end
            if (owner(cell01) != 2'b00 && owner(cell01) != owner(cell10)) begin
              dmg01 <= dmg01 + compute_damage(owner(cell10), owner(cell01), p1_atk_u, p1_arm_u, p2_atk_u, p2_arm_u);
            end
            if (owner(cell11) != 2'b00 && owner(cell11) != owner(cell10)) begin
              dmg11 <= dmg11 + compute_damage(owner(cell10), owner(cell11), p1_atk_u, p1_arm_u, p2_atk_u, p2_arm_u);
            end
          end

          // Attacker at (1,1)
          if (owner(cell11) != 2'b00) begin
            // neighbors: (0,0),(0,1),(1,0)
            if (owner(cell00) != 2'b00 && owner(cell00) != owner(cell11)) begin
              dmg00 <= dmg00 + compute_damage(owner(cell11), owner(cell00), p1_atk_u, p1_arm_u, p2_atk_u, p2_arm_u);
            end
            if (owner(cell01) != 2'b00 && owner(cell01) != owner(cell11)) begin
              dmg01 <= dmg01 + compute_damage(owner(cell11), owner(cell01), p1_atk_u, p1_arm_u, p2_atk_u, p2_arm_u);
            end
            if (owner(cell10) != 2'b00 && owner(cell10) != owner(cell11)) begin
              dmg10 <= dmg10 + compute_damage(owner(cell11), owner(cell10), p1_atk_u, p1_arm_u, p2_atk_u, p2_arm_u);
            end
          end
        end

        APPLY_ATTACK: begin
          // Apply accumulated damage simultaneously, clamp HP >= 0
          integer nhp;

          // cell00
          if (owner(cell00) != 2'b00 && hp(cell00) > 0) begin
            nhp = hp(cell00) - dmg00;
            if (nhp <= 0)
              cell00 <= 8'd0;
            else
              cell00 <= make_cell(owner(cell00), clamp_hp(nhp));
          end else begin
            cell00 <= cell00; // no change
          end

          // cell01
          if (owner(cell01) != 2'b00 && hp(cell01) > 0) begin
            nhp = hp(cell01) - dmg01;
            if (nhp <= 0)
              cell01 <= 8'd0;
            else
              cell01 <= make_cell(owner(cell01), clamp_hp(nhp));
          end else begin
            cell01 <= cell01;
          end

          // cell10
          if (owner(cell10) != 2'b00 && hp(cell10) > 0) begin
            nhp = hp(cell10) - dmg10;
            if (nhp <= 0)
              cell10 <= 8'd0;
            else
              cell10 <= make_cell(owner(cell10), clamp_hp(nhp));
          end else begin
            cell10 <= cell10;
          end

          // cell11
          if (owner(cell11) != 2'b00 && hp(cell11) > 0) begin
            nhp = hp(cell11) - dmg11;
            if (nhp <= 0)
              cell11 <= 8'd0;
            else
              cell11 <= make_cell(owner(cell11), clamp_hp(nhp));
          end else begin
            cell11 <= cell11;
          end
        end

        COMPUTE_MOVE: begin
          // Determine if each unit attacked (has adjacent enemy in previous state). Here we recompute using current cell values.
          // For movement, only non-attacking units may move.

          // Neighbors per cell, using out-of-bounds as empty (00 owner)
          // For 2x2, explicitly list combinational neighbors for has_adj_enemy.

          // cell00 neighbors: (0,1),(1,0),(1,1); others treated as empty
          // Build virtual neighbors as 8 args
          // Order doesn't matter for has_adj_enemy, we just pass all real neighbors.

          // Whether each cell had an adjacent enemy
          reg att00, att01, att10, att11;

          att00 <= has_adj_enemy(
            cell00,
            cell01, cell10, cell11,
            8'd0, 8'd0, 8'd0, 8'd0
          );

          att01 <= has_adj_enemy(
            cell01,
            cell00, cell10, cell11,
            8'd0, 8'd0, 8'd0, 8'd0
          );

          att10 <= has_adj_enemy(
            cell10,
            cell00, cell01, cell11,
            8'd0, 8'd0, 8'd0, 8'd0
          );

          att11 <= has_adj_enemy(
            cell11,
            cell00, cell01, cell10,
            8'd0, 8'd0, 8'd0, 8'd0
          );

          // Default: no movement
          mv_src00_dest <= 2'b00; // (0,0)
          mv_src01_dest <= 2'b01; // (0,1)
          mv_src10_dest <= 2'b10; // (1,0)
          mv_src11_dest <= 2'b11; // (1,1)

          // Compute destinations only for alive, non-attacking units
          if (owner(cell00) != 2'b00 && hp(cell00) > 0 && !att00) begin
            mv_src00_dest <= choose_move_dest(1'b0,1'b0,owner(cell00),cell00,cell01,cell10,cell11);
          end
          if (owner(cell01) != 2'b00 && hp(cell01) > 0 && !att01) begin
            mv_src01_dest <= choose_move_dest(1'b0,1'b1,owner(cell01),cell00,cell01,cell10,cell11);
          end
          if (owner(cell10) != 2'b00 && hp(cell10) > 0 && !att10) begin
            mv_src10_dest <= choose_move_dest(1'b1,1'b0,owner(cell10),cell00,cell01,cell10,cell11);
          end
          if (owner(cell11) != 2'b00 && hp(cell11) > 0 && !att11) begin
            mv_src11_dest <= choose_move_dest(1'b1,1'b1,owner(cell11),cell00,cell01,cell10,cell11);
          end
        end

        APPLY_MOVE: begin
          // Resolve movements with conflicts: northernmost, then westernmost priority.
          // We'll build next_cellXX based on destinations.

          // Start with all empty
          next_cell00 = 8'd0;
          next_cell01 = 8'd0;
          next_cell10 = 8'd0;
          next_cell11 = 8'd0;

          // Helper task-like process via precedence for each dest
          // For each source, we know its original cell and dest encoding.

          // Function to write if empty
          // Implement inline with ifs and priority by source order.

          // Priority order of sources for conflicts: northernmost then westernmost
          // => (0,0) > (0,1) > (1,0) > (1,1)

          // Source (0,0)
          if (owner(cell00) != 2'b00 && hp(cell00) > 0) begin
            case (mv_src00_dest)
              2'b00: if (next_cell00 == 8'd0) next_cell00 = cell00;
              2'b01: if (next_cell01 == 8'd0) next_cell01 = cell00;
              2'b10: if (next_cell10 == 8'd0) next_cell10 = cell00;
              2'b11: if (next_cell11 == 8'd0) next_cell11 = cell00;
            endcase
          end

          // Source (0,1)
          if (owner(cell01) != 2'b00 && hp(cell01) > 0) begin
            case (mv_src01_dest)
              2'b00: if (next_cell00 == 8'd0) next_cell00 = cell01;
              2'b01: if (next_cell01 == 8'd0) next_cell01 = cell01;
              2'b10: if (next_cell10 == 8'd0) next_cell10 = cell01;
              2'b11: if (next_cell11 == 8'd0) next_cell11 = cell01;
            endcase
          end

          // Source (1,0)
          if (owner(cell10) != 2'b00 && hp(cell10) > 0) begin
            case (mv_src10_dest)
              2'b00: if (next_cell00 == 8'd0) next_cell00 = cell10;
              2'b01: if (next_cell01 == 8'd0) next_cell01 = cell10;
              2'b10: if (next_cell10 == 8'd0) next_cell10 = cell10;
              2'b11: if (next_cell11 == 8'd0) next_cell11 = cell10;
            endcase
          end

          // Source (1,1)
          if (owner(cell11) != 2'b00 && hp(cell11) > 0) begin
            case (mv_src11_dest)
              2'b00: if (next_cell00 == 8'd0) next_cell00 = cell11;
              2'b01: if (next_cell01 == 8'd0) next_cell01 = cell11;
              2'b10: if (next_cell10 == 8'd0) next_cell10 = cell11;
              2'b11: if (next_cell11 == 8'd0) next_cell11 = cell11;
            endcase
          end

          // Commit
          cell00 <= next_cell00;
          cell01 <= next_cell01;
          cell10 <= next_cell10;
          cell11 <= next_cell11;
        end

        REGEN: begin
          // Regeneration: +1 HP if live and HP < 35
          integer rhp;

          if (owner(cell00) != 2'b00 && hp(cell00) > 0 && hp(cell00) < 35) begin
            rhp = hp(cell00) + 1;
            cell00 <= make_cell(owner(cell00), clamp_hp(rhp));
          end
          if (owner(cell01) != 2'b00 && hp(cell01) > 0 && hp(cell01) < 35) begin
            rhp = hp(cell01) + 1;
            cell01 <= make_cell(owner(cell01), clamp_hp(rhp));
          end
          if (owner(cell10) != 2'b00 && hp(cell10) > 0 && hp(cell10) < 35) begin
            rhp = hp(cell10) + 1;
            cell10 <= make_cell(owner(cell10), clamp_hp(rhp));
          end
          if (owner(cell11) != 2'b00 && hp(cell11) > 0 && hp(cell11) < 35) begin
            rhp = hp(cell11) + 1;
            cell11 <= make_cell(owner(cell11), clamp_hp(rhp));
          end

          // Increment turn counter at end of full turn sequence
          if (cur_turn < target_turns)
            cur_turn <= cur_turn + 1;
        end

        DONE: begin
          // Pack final_grid: 2 bits per cell owner from final states
          final_grid <= {owner(cell00), owner(cell01), owner(cell10), owner(cell11)};
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

endmodule