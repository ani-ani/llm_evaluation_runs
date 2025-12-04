module zerg_rush_simulator(
  input clk,
  input rst_n,
  input start,
  input [1:0] p1_attack_upgrade,
  input [1:0] p1_armor_upgrade,
  input [1:0] p2_attack_upgrade,
  input [1:0] p2_armor_upgrade,
  input [7:0] init_grid, // Flattened 2x2 grid as 8-bit: [row0_col0, row0_col1, row1_col0, row1_col1]*2
  input [1:0] turns, // 0-3 turns
  output reg [7:0] final_grid,
  output reg done
);

  // Grid layout (indices):
  // 0  1
  // 2  3

  typedef enum logic [2:0] {
    IDLE = 3'd0,
    COMPUTE_ATTACK = 3'd1,
    APPLY_ATTACK = 3'd2,
    COMPUTE_MOVE = 3'd3,
    APPLY_MOVE = 3'd4,
    REGEN = 3'd5,
    DONE = 3'd6
  } state_t;

  typedef enum logic [2:0] {
    N = 3'd0,
    NE = 3'd1,
    E = 3'd2,
    SE = 3'd3,
    S = 3'd4,
    SW = 3'd5,
    W = 3'd6,
    NW = 3'd7
  } dir_t;

  // Per-cell storage: 8 bits = {6-bit HP, 2-bit occupancy}
  // occupancy: 2'b00 empty, 2'b01 P1, 2'b10 P2
  reg [7:0] grid_r [0:3];
  reg [7:0] next_grid_r [0:3];

  // Movement preferences (movement phase) and flags
  reg [1:0] pref_r [0:3];    // 2-bit numeric preference tie-breaker: 00=N,01=NE,10=E,11=SE,12=SW,13=W,14=NW
  reg [2:0] pref_dir_r [0:3]; // actual direction selected (one-hot per dir_t)
  reg is_moving_r [0:3];
  reg is_moving_next [0:3];

  reg [1:0] p1_attack_r, p1_armor_r;
  reg [1:0] p2_attack_r, p2_armor_r;

  reg [1:0] turns_left_r;
  reg [1:0] max_turns_r;

  // Two 5-cycle turn counters: one for internal control, one to gate output validity
  reg [2:0] turn_counter_r;        // 0..4
  reg [2:0] out_turn_counter_r;    // 0..4

  reg [2:0] dmg_cmb_r [0:3]; // Damage accumulation per target (clamped to 6 bits but fits in 3 bits max for 4 attackers)

  // Temp damage compute (unsigned + signed wrappers for min/max)
  logic [5:0] dmg_i [0:3]; // computed per attacker

  reg [2:0] state_r, state_next;

  // Helper: clamp 3-bit damage to at most 6 bits for HP
  function [5:0] clamp_dmg;
    input [7:0] dmg; // 0..255; will be small here
    clamp_dmg = (dmg > 6'd63) ? 6'd63 : dmg[5:0];
  endfunction

  // Manhattan distance between two cells on a 2x2 grid, no wrap
  function [1:0] manhattan;
    input [1:0] a, b;
    logic [1:0] dx, dy;
    dx = (a[0] > b[0]) ? (a[0] - b[0]) : (b[0] - a[0]); // col diff
    dy = (a[1] > b[1]) ? (a[1] - b[1]) : (b[1] - a[1]); // row diff
    manhattan = dx + dy;
  endfunction

  // Extractors
  function [1:0] get_occ;
    input [7:0] cell;
    get_occ = cell[1:0];
  endfunction
  function [5:0] get_hp;
    input [7:0] cell;
    get_hp = cell[7:2];
  endfunction
  function [7:0] make_cell;
    input [1:0] occ;
    input [5:0] hp;
    make_cell = {hp, occ};
  endfunction
  function [1:0] player_of;
    input [1:0] occ;
    player_of = (occ == 2'b01) ? 2'd1 : (occ == 2'b10 ? 2'd2 : 2'd0);
  endfunction

  // Map direction to delta (row, col)
  function [1:0] d_row;
    input [2:0] d;
    case (d)
      N:  d_row = 2'b10; // -1
      NE: d_row = 2'b10;
      E:  d_row = 2'b00;
      SE: d_row = 2'b01; // +1
      S:  d_row = 2'b01;
      SW: d_row = 2'b01;
      W:  d_row = 2'b00;
      NW: d_row = 2'b10;
      default: d_row = 2'b00;
    endcase
  endfunction
  function [1:0] d_col;
    input [2:0] d;
    case (d)
      N:  d_col = 2'b00;
      NE: d_col = 2'b01;
      E:  d_col = 2'b01;
      SE: d_col = 2'b01;
      S:  d_col = 2'b00;
      SW: d_col = 2'b10;
      W:  d_col = 2'b10;
      NW: d_col = 2'b10;
      default: d_col = 2'b00;
    endcase
  endfunction

  // Priority ordering for conflict resolution (northmost then westernmost)
  function [1:0] priority_rank;
    input [1:0] idx;
    case (idx)
      2'd0: priority_rank = 2'd0; // row0,col0 (top-left) highest
      2'd1: priority_rank = 2'd1; // row0,col1
      2'd2: priority_rank = 2'd2; // row1,col0
      2'd3: priority_rank = 2'd3; // row1,col1
      default: priority_rank = 2'd0;
    endcase
  endfunction

  // Convert 'pref' to direction one-hot for readability
  function [7:0] pref_to_onehot;
    input [1:0] p;
    case (p)
      2'd0: pref_to_onehot = 8'b00000001; // N
      2'd1: pref_to_onehot = 8'b00000010; // NE
      2'd2: pref_to_onehot = 8'b00000100; // E
      2'd3: pref_to_onehot = 8'b00001000; // SE
      2'd4: pref_to_onehot = 8'b00010000; // S
      2'd5: pref_to_onehot = 8'b00100000; // SW
      2'd6: pref_to_onehot = 8'b01000000; // W
      2'd7: pref_to_onehot = 8'b10000000; // NW
      default: pref_to_onehot = 8'b00000000;
    endcase
  endfunction

  // Find nearest enemy by Manhattan distance; tie-break by direction priority N>NE>E>SE>S>SW>W>NW
  // Returns {found, dist[1:0], dir[2:0]}
  function [5:0] nearest_enemy_info;
    input [1:0] src_idx;
    input [1:0] my_player;
    reg [1:0] min_dist;
    reg [2:0] best_dir;
    reg found;
    integer i;
    reg [1:0] nidx;
    begin
      min_dist = 2'd3; // max dist on 2x2 is 2
      best_dir = 3'd0;
      found = 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        nidx = src_idx;
        case (i)
          0: nidx = (src_idx[1] == 1'b1) ? src_idx : 2'd255; // N (invalid if row=1)
          1: nidx = (src_idx[1] == 1'b1) && (src_idx[0] == 1'b0) ? 2'd1 : 2'd255; // NE
          2: nidx = (src_idx[0] == 1'b0) ? 2'd255 : 2'd255; // E (always invalid, no wrap)
          3: nidx = 2'd255; // SE (no wrap)
          4: nidx = (src_idx[1] == 1'b0) ? src_idx : 2'd255; // S (invalid if row=0)
          5: nidx = 2'd255; // SW (no wrap)
          6: nidx = (src_idx[0] == 1'b1) ? src_idx : 2'd255; // W (invalid if col=0)
          7: nidx = 2'd255; // NW (no wrap)
        endcase
        if (nidx != 2'd255) begin
          if ((get_occ(grid_r[nidx]) != 2'b00) && (player_of(get_occ(grid_r[nidx])) != my_player)) begin
            if (!found || (manhattan(src_idx, nidx) < min_dist) ||
                ((manhattan(src_idx, nidx) == min_dist) && (i < best_dir))) begin
              min_dist = manhattan(src_idx, nidx);
              best_dir = i[2:0];
              found = 1'b1;
            end
          end
        end
      end
      nearest_enemy_info = {found, min_dist, best_dir};
    end
  endfunction

  // Step 1: compute damage per attacker
  always @(*) begin
    integer i;
    for (i = 0; i < 4; i = i + 1) begin
      dmg_i[i] = 6'd0;
    end
    for (i = 0; i < 4; i = i + 1) begin
      if (get_occ(grid_r[i]) != 2'b00) begin
        // Find any enemy adjacent (no wrap) in 8 directions
        reg [7:0] occs;
        integer j;
        occs = 8'd0;
        for (j = 0; j < 8; j = j + 1) begin
          // For each direction, map to valid index (if any)
          case (j)
            0: if (i[1] == 1'b1) occs[0] = get_occ(grid_r[i-2]); else occs[0] = 2'b00; // N
            1: if (i[1] == 1'b1 && i[0] == 1'b0) occs[1] = get_occ(grid_r[1]); else occs[1] = 2'b00; // NE (i=2 -> 1)
            2: occs[2] = 2'b00; // E not allowed
            3: occs[3] = 2'b00; // SE not allowed
            4: if (i[1] == 1'b0) occs[4] = get_occ(grid_r[i+2]); else occs[4] = 2'b00; // S
            5: occs[5] = 2'b00; // SW not allowed
            6: if (i[0] == 1'b1) occs[6] = get_occ(grid_r[i-1]); else occs[6] = 2'b00; // W
            7: occs[7] = 2'b00; // NW not allowed
          endcase
        end
        // Determine if has any enemy neighbor
        reg has_enemy;
        has_enemy = 1'b0;
        for (j = 0; j < 8; j = j + 1) begin
          if (occs[j] != 2'b00 && player_of(occs[j]) != player_of(get_occ(grid_r[i]))) begin
            has_enemy = 1'b1;
            j = 8; // break
          end
        end
        if (has_enemy) begin
          // Damage = (5 + attacker_attack) - defender_armor, min 1
          if (player_of(get_occ(grid_r[i])) == 2'd1) begin
            reg [7:0] tmp;
            tmp = 8'd5 + {6'd0, p1_attack_r} - {6'd0, p1_armor_r}; // Use attacker's armor only for clamped formula
            dmg_i[i] = (tmp[7]) ? 6'd1 : clamp_dmg(tmp);
          end else begin
            reg [7:0] tmp;
            tmp = 8'd5 + {6'd0, p2_attack_r} - {6'd0, p2_armor_r};
            dmg_i[i] = (tmp[7]) ? 6'd1 : clamp_dmg(tmp);
          end
        end
      end
    end
  end

  // APPLY_ATTACK step logic
  always @(*) begin
    integer i;
    for (i = 0; i < 4; i = i + 1) begin
      next_grid_r[i] = grid_r[i];
    end
    for (i = 0; i < 4; i = i + 1) begin
      if (dmg_cmb_r[i] > 3'd0 && get_occ(grid_r[i]) != 2'b00) begin
        reg [5:0] new_hp;
        new_hp = (get_hp(grid_r[i]) > {3'd0, dmg_cmb_r[i]}) ? (get_hp(grid_r[i]) - {3'd0, dmg_cmb_r[i]}) : 6'd0;
        if (new_hp == 6'd0) begin
          next_grid_r[i] = make_cell(2'b00, 6'd0);
        end else begin
          next_grid_r[i] = make_cell(get_occ(grid_r[i]), new_hp);
        end
      end
    end
  end

  // COMPUTE_MOVE: determine preference and moving flags
  always @(*) begin
    integer i;
    for (i = 0; i < 4; i = i + 1) begin
      pref_r[i] = 2'd0;
      pref_dir_r[i] = 3'd0;
      is_moving_next[i] = 1'b0;
    end
    for (i = 0; i < 4; i = i + 1) begin
      if (get_occ(grid_r[i]) != 2'b00) begin
        reg [5:0] info;
        info = nearest_enemy_info(i, player_of(get_occ(grid_r[i])));
        if (info[5] == 1'b1) begin
          // enemy found, choose move dir to reduce distance
          reg [2:0] d;
          reg [1:0] src_r, src_c, dst_r, dst_c;
          src_r = i[1]; src_c = i[0];
          d = info[2:0];
          dst_r = src_r + (d_row(d) ^ 2'b10) + (d_row(d)[1] ? 2'b0 : 2'b0); // just to avoid lint
          dst_c = src_c + (d_col(d) ^ 2'b10) + (d_col(d)[1] ? 2'b0 : 2'b0);  // same
          // We computed with positive deltas earlier; adjust to signed effect:
          case (d)
            N:  begin dst_r = (src_r == 1'b1) ? (src_r - 1'b1) : src_r; dst_c = src_c; end
            NE: begin dst_r = (src_r == 1'b1) ? (src_r - 1'b1) : src_r; dst_c = (src_c == 1'b0) ? (src_c + 1'b1) : src_c; end
            E:  begin dst_r = src_r; dst_c = (src_c == 1'b0) ? (src_c + 1'b1) : src_c; end
            SE: begin dst_r = (src_r == 1'b0) ? (src_r + 1'b1) : src_r; dst_c = (src_c == 1'b0) ? (src_c + 1'b1) : src_c; end
            S:  begin dst_r = (src_r == 1'b0) ? (src_r + 1'b1) : src_r; dst_c = src_c; end
            SW: begin dst_r = (src_r == 1'b0) ? (src_r + 1'b1) : src_r; dst_c = (src_c == 1'b1) ? (src_c - 1'b1) : src_c; end
            W:  begin dst_r = src_r; dst_c = (src_c == 1'b1) ? (src_c - 1'b1) : src_c; end
            NW: begin dst_r = (src_r == 1'b1) ? (src_r - 1'b1) : src_r; dst_c = (src_c == 1'b1) ? (src_c - 1'b1) : src_c; end
            default: ;
          endcase
          // Only valid if in bounds (2x2)
          if (dst_r <= 2'd1 && dst_c <= 2'd1) begin
            // Only move if dest empty and not already occupied by ally in next_grid_r (if attack just applied)
            if (get_occ(next_grid_r[{dst_r, dst_c}]) == 2'b00) begin
              // Compute preference code to break ties: N,NE,E,SE,S,SW,W,NW mapped to 0..7
              case (d)
                N:  pref_r[i] = 2'd0;
                NE: pref_r[i] = 2'd1;
                E:  pref_r[i] = 2'd2;
                SE: pref_r[i] = 2'd3;
                S:  pref_r[i] = 2'd4;
                SW: pref_r[i] = 2'd5;
                W:  pref_r[i] = 2'd6;
                NW: pref_r[i] = 2'd7;
                default: pref_r[i] = 2'd0;
              endcase
              pref_dir_r[i] = d;
              is_moving_next[i] = 1'b1;
            end
          end
        end
      end
    end
  end

  // APPLY_MOVE: move non-attacking zerglings to preferred empty cell, resolve conflicts by priority
  always @(*) begin
    integer i, j;
    reg [7:0] dest_map [0:3]; // which source moves into dest (bitmask over 4 sources)
    reg [1:0] chosen_src [0:3];

    for (i = 0; i < 4; i = i + 1) begin
      dest_map[i] = 8'd0;
      chosen_src[i] = 2'd0;
    end

    // Collect desires
    for (i = 0; i < 4; i = i + 1) begin
      if (is_moving_r[i]) begin
        // Determine destination based on pref_dir_r[i]
        reg [1:0] src_r, src_c, dst_r, dst_c;
        src_r = i[1]; src_c = i[0];
        case (pref_dir_r[i])
          N:  begin dst_r = (src_r == 1'b1) ? (src_r - 1'b1) : src_r; dst_c = src_c; end
          NE: begin dst_r = (src_r == 1'b1) ? (src_r - 1'b1) : src_r; dst_c = (src_c == 1'b0) ? (src_c + 1'b1) : src_c; end
          E:  begin dst_r = src_r; dst_c = (src_c == 1'b0) ? (src_c + 1'b1) : src_c; end
          SE: begin dst_r = (src_r == 1'b0) ? (src_r + 1'b1) : src_r; dst_c = (src_c == 1'b0) ? (src_c + 1'b1) : src_c; end
          S:  begin dst_r = (src_r == 1'b0) ? (src_r + 1'b1) : src_r; dst_c = src_c; end
          SW: begin dst_r = (src_r == 1'b0) ? (src_r + 1'b1) : src_r; dst_c = (src_c == 1'b1) ? (src_c - 1'b1) : src_c; end
          W:  begin dst_r = src_r; dst_c = (src_c == 1'b1) ? (src_c - 1'b1) : src_c; end
          NW: begin dst_r = (src_r == 1'b1) ? (src_r - 1'b1) : src_r; dst_c = (src_c == 1'b1) ? (src_c - 1'b1) : src_c; end
          default: begin dst_r = src_r; dst_c = src_c; end
        endcase
        if (dst_r <= 2'd1 && dst_c <= 2'd1) begin
          // Add to bitmask for that destination
          dest_map[{dst_r, dst_c}] = dest_map[{dst_r, dst_c}] | (1 << i);
        end
      end
    end

    // For each destination, select the source with highest priority (northmost then westernmost)
    for (i = 0; i < 4; i = i + 1) begin
      reg [7:0] mask;
      reg [1:0] best;
      reg [1:0] best_rank;
      mask = dest_map[i];
      best = 2'd0;
      best_rank = 2'd3; // high rank first; lower numeric rank wins
      if (mask != 8'd0) begin
        for (j = 0; j < 4; j = j + 1) begin
          if (mask[j]) begin
            if (priority_rank(j) < best_rank) begin
              best_rank = priority_rank(j);
              best = j[1:0];
            end
          end
        end
        chosen_src[i] = best;
      end else begin
        chosen_src[i] = 2'd0;
      end
    end

    // Build next_grid_r after move
    for (i = 0; i < 4; i = i + 1) begin
      next_grid_r[i] = next_grid_r[i]; // keep after attack step
    end
    // Clear all current cells (they will be either kept or moved into destination)
    for (i = 0; i < 4; i = i + 1) begin
      if (get_occ(next_grid_r[i]) != 2'b00 && !is_moving_r[i]) begin
        // stays
      end else begin
        next_grid_r[i] = make_cell(2'b00, 6'd0);
      end
    end
    // Place moved units
    for (i = 0; i < 4; i = i + 1) begin
      if (dest_map[i] != 8'd0) begin
        // someone moves to i
        if (get_occ(next_grid_r[i]) == 2'b00) begin
          reg [1:0] src;
          src = chosen_src[i];
          // Ensure source actually was moving
          if (is_moving_r[src]) begin
            next_grid_r[i] = grid_r[src];
          end
        end
      end
    end
    // Stationary survivors that didn't move: keep original cells
    for (i = 0; i < 4; i = i + 1) begin
      if (get_occ(next_grid_r[i]) == 2'b00 && !is_moving_r[i]) begin
        // nothing, already cleared if it had moved flag
      end
      if (get_occ(next_grid_r[i]) == 2'b00 && is_moving_r[i]) begin
        // if it intended to move but destination map empty (should not happen), stay
        next_grid_r[i] = grid_r[i];
      end
    end
  end

  // State machine and sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_r <= IDLE;
      done <= 1'b0;
      final_grid <= 8'd0;
      turn_counter_r <= 3'd0;
      out_turn_counter_r <= 3'd0;
      p1_attack_r <= 2'd0;
      p1_armor_r <= 2'd0;
      p2_attack_r <= 2'd0;
      p2_armor_r <= 2'd0;
      max_turns_r <= 2'd0;
      turns_left_r <= 2'd0;
      grid_r[0] <= 8'd0;
      grid_r[1] <= 8'd0;
      grid_r[2] <= 8'd0;
      grid_r[3] <= 8'd0;
      pref_r[0] <= 2'd0; pref_r[1] <= 2'd0; pref_r[2] <= 2'd0; pref_r[3] <= 2'd0;
      pref_dir_r[0] <= 3'd0; pref_dir_r[1] <= 3'd0; pref_dir_r[2] <= 3'd0; pref_dir_r[3] <= 3'd0;
      is_moving_r[0] <= 1'b0; is_moving_r[1] <= 1'b0; is_moving_r[2] <= 1'b0; is_moving_r[3] <= 1'b0;
      dmg_cmb_r[0] <= 3'd0; dmg_cmb_r[1] <= 3'd0; dmg_cmb_r[2] <= 3'd0; dmg_cmb_r[3] <= 3'd0;
    end else begin
      // Defaults
      state_r <= state_next;
      done <= 1'b0;
      final_grid <= final_grid; // keep unless updated in DONE
      // Turn counters
      turn_counter_r <= turn_counter_r;
      out_turn_counter_r <= out_turn_counter_r;

      // Keep latches stable unless written
      p1_attack_r <= p1_attack_r;
      p1_armor_r <= p1_armor_r;
      p2_attack_r <= p2_attack_r;
      p2_armor_r <= p2_armor_r;
      max_turns_r <= max_turns_r;
      turns_left_r <= turns_left_r;
      grid_r[0] <= grid_r[0];
      grid_r[1] <= grid_r[1];
      grid_r[2] <= grid_r[2];
      grid_r[3] <= grid_r[3];
      pref_r[0] <= pref_r[0]; pref_r[1] <= pref_r[1]; pref_r[2] <= pref_r[2]; pref_r[3] <= pref_r[3];
      pref_dir_r[0] <= pref_dir_r[0]; pref_dir_r[1] <= pref_dir_r[1]; pref_dir_r[2] <= pref_dir_r[2]; pref_dir_r[3] <= pref_dir_r[3];
      is_moving_r[0] <= is_moving_r[0]; is_moving_r[1] <= is_moving_r[1]; is_moving_r[2] <= is_moving_r[2]; is_moving_r[3] <= is_moving_r[3];
      dmg_cmb_r[0] <= dmg_cmb_r[0]; dmg_cmb_r[1] <= dmg_cmb_r[1]; dmg_cmb_r[2] <= dmg_cmb_r[2]; dmg_cmb_r[3] <= dmg_cmb_r[3];

      case (state_r)
        IDLE: begin
          if (start) begin
            // Sample upgrades and init grid
            p1_attack_r <= p1_attack_upgrade;
            p1_armor_r <= p1_armor_upgrade;
            p2_attack_r <= p2_attack_upgrade;
            p2_armor_r <= p2_armor_upgrade;
            max_turns_r <= turns;
            turns_left_r <= turns;
            turn_counter_r <= 3'd0;
            out_turn_counter_r <= 3'd0;
            // Map 8-bit init_grid (2 bits per cell) into our per-cell 8-bit storage with HP=0
            grid_r[0] <= {6'd0, init_grid[1:0]};
            grid_r[1] <= {6'd0, init_grid[3:2]};
            grid_r[2] <= {6'd0, init_grid[5:4]};
            grid_r[3] <= {6'd0, init_grid[7:6]};
            // Set move state default
            pref_r[0] <= 2'd0; pref_r[1] <= 2'd0; pref_r[2] <= 2'd0; pref_r[3] <= 2'd0;
            pref_dir_r[0] <= 3'd0; pref_dir_r[1] <= 3'd0; pref_dir_r[2] <= 3'd0; pref_dir_r[3] <= 3'd0;
            is_moving_r[0] <= 1'b0; is_moving_r[1] <= 1'b0; is_moving_r[2] <= 1'b0; is_moving_r[3] <= 1'b0;
            dmg_cmb_r[0] <= 3'd0; dmg_cmb_r[1] <= 3'd0; dmg_cmb_r[2] <= 3'd0; dmg_cmb_r[3] <= 3'd0;
            state_next <= COMPUTE_ATTACK;
          end else begin
            state_next <= IDLE;
          end
        end

        COMPUTE_ATTACK: begin
          // Accumulate damages into dmg_cmb_r
          dmg_cmb_r[0] <= (dmg_i[0] > 3'd0) ? dmg_i[0][2:0] : 3'd0;
          dmg_cmb_r[1] <= (dmg_i[1] > 3'd0) ? dmg_i[1][2:0] : 3'd0;
          dmg_cmb_r[2] <= (dmg_i[2] > 3'd0) ? dmg_i[2][2:0] : 3'd0;
          dmg_cmb_r[3] <= (dmg_i[3] > 3'd0) ? dmg_i[3][2:0] : 3'd0;
          // For moving flags: only non-attacking units move
          is_moving_r[0] <= (get_occ(grid_r[0]) != 2'b00 && dmg_i[0] == 6'd0);
          is_moving_r[1] <= (get_occ(grid_r[1]) != 2'b00 && dmg_i[1] == 6'd0);
          is_moving_r[2] <= (get_occ(grid_r[2]) != 2'b00 && dmg_i[2] == 6'd0);
          is_moving_r[3] <= (get_occ(grid_r[3]) != 2'b00 && dmg_i[3] == 6'd0);
          state_next <= APPLY_ATTACK;
        end

        APPLY_ATTACK: begin
          // Grid already updated in combinational block next_grid_r
          grid_r[0] <= next_grid_r[0];
          grid_r[1] <= next_grid_r[1];
          grid_r[2] <= next_grid_r[2];
          grid_r[3] <= next_grid_r[3];
          // Reset damage
          dmg_cmb_r[0] <= 3'd0; dmg_cmb_r[1] <= 3'd0; dmg_cmb_r[2] <= 3'd0; dmg_cmb_r[3] <= 3'd0;
          state_next <= COMPUTE_MOVE;
        end

        COMPUTE_MOVE: begin
          // Preferences already updated in combinational block
          pref_r[0] <= pref_r[0]; pref_r[1] <= pref_r[1]; pref_r[2] <= pref_r[2]; pref_r[3] <= pref_r[3];
          pref_dir_r[0] <= pref_dir_r[0]; pref_dir_r[1] <= pref_dir_r[1]; pref_dir_r[2] <= pref_dir_r[2]; pref_dir_r[3] <= pref_dir_r[3];
          is_moving_r[0] <= is_moving_next[0]; is_moving_r[1] <= is_moving_next[1]; is_moving_r[2] <= is_moving_next[2]; is_moving_r[3] <= is_moving_next[3];
          state_next <= APPLY_MOVE;
        end

        APPLY_MOVE: begin
          // Grid already updated in combinational block next_grid_r
          grid_r[0] <= next_grid_r[0];
          grid_r[1] <= next_grid_r[1];
          grid_r[2] <= next_grid_r[2];
          grid_r[3] <= next_grid_r[3];
          state_next <= REGEN;
        end

        REGEN: begin
          // Regenerate HP by 1 if alive and HP < 35
          grid_r[0] <= (get_occ(grid_r[0]) != 2'b00 && get_hp(grid_r[0]) < 6'd35) ? make_cell(get_occ(grid_r[0]), get_hp(grid_r[0]) + 6'd1) : grid_r[0];
          grid_r[1] <= (get_occ(grid_r[1]) != 2'b00 && get_hp(grid_r[1]) < 6'd35) ? make_cell(get_occ(grid_r[1]), get_hp(grid_r[1]) + 6'd1) : grid_r[1];
          grid_r[2] <= (get_occ(grid_r[2]) != 2'b00 && get_hp(grid_r[2]) < 6'd35) ? make_cell(get_occ(grid_r[2]), get_hp(grid_r[2]) + 6'd1) : grid_r[2];
          grid_r[3] <= (get_occ(grid_r[3]) != 2'b00 && get_hp(grid_r[3]) < 6'd35) ? make_cell(get_occ(grid_r[3]), get_hp(grid_r[3]) + 6'd1) : grid_r[3];

          // Advance turn counter (every 5 cycles)
          if (turn_counter_r == 3'd4) begin
            turn_counter_r <= 3'd0;
            if (turns_left_r > 2'd0) turns_left_r <= turns_left_r - 1;
          end else begin
            turn_counter_r <= turn_counter_r + 1;
          end
          // Advance output turn counter
          if (out_turn_counter_r == 3'd4) out_turn_counter_r <= 3'd0;
          else out_turn_counter_r <= out_turn_counter_r + 1;

          if (turns_left_r == 2'd0 && turn_counter_r == 3'd4) begin
            state_next <= DONE;
          end else begin
            state_next <= COMPUTE_ATTACK;
          end
        end

        DONE: begin
          // Pack final occupancy into 8-bit final_grid: 2 bits per cell in order 0..3
          final_grid <= {grid_r[3][1:0], grid_r[2][1:0], grid_r[1][1:0], grid_r[0][1:0]};
          done <= 1'b1;
          // Keep output turn counter running up to 5 cycles after entry
          if (out_turn_counter_r == 3'd4) out_turn_counter_r <= 3'd0;
          else out_turn_counter_r <= out_turn_counter_r + 1;
          // Latch final state until reset or new start
          state_next <= DONE;
        end

        default: state_next <= IDLE;
      endcase
    end
  end

endmodule
