module planet_collision_sim (
  input clk,
  input rst_n,
  input start,
  input [3:0][8:0] masses_in,
  input [3:0][2:0] x_in, y_in, z_in,
  input [3:0][3:0] vx_in, vy_in, vz_in,
  output reg [1:0] planet_count,
  output reg [3:0][8:0] masses_out,
  output reg [3:0][2:0] x_out, y_out, z_out,
  output reg [3:0][3:0] vx_out, vy_out, vz_out,
  output reg done
);
  parameter MAX_CYCLES = 8;
  parameter MAX_PLANETOIDS = 4;
  parameter GRID_W = 3; // 3-bit grid: 0..7
  
  // State
  logic started_r, started_q;
  logic [2:0] cycle_r, cycle_q; // 0..7
  logic [MAX_PLANETOIDS-1:0] active_r, active_q;
  logic [MAX_PLANETOIDS-1:0][8:0] mass_r, mass_q;
  logic [MAX_PLANETOIDS-1:0][GRID_W-1:0] x_r, x_q, y_r, y_q, z_r, z_q;
  logic signed [MAX_PLANETOIDS-1:0][3:0] vx_r, vx_q, vy_r, vy_q, vz_r, vz_q;
  
  // Next-state wires
  logic started_next;
  logic [2:0] cycle_next;
  logic [MAX_PLANETOIDS-1:0] active_next;
  logic [MAX_PLANETOIDS-1:0][8:0] mass_next;
  logic [MAX_PLANETOIDS-1:0][GRID_W-1:0] x_next, y_next, z_next;
  logic signed [MAX_PLANETOIDS-1:0][3:0] vx_next, vy_next, vz_next;
  
  // Store last positions (for tie-breaking) when needed
  logic [MAX_PLANETOIDS-1:0][GRID_W-1:0] last_x_r, last_y_r, last_z_r;
  
  // Helpers: position hash and comparison
  function [8:0] pos_hash;
    input [GRID_W-1:0] x, y, z;
    pos_hash = {x, y, z}; // 9-bit concat
  endfunction
  
  function [2:0] mod3 signed;
    input signed [2:0] a;
    mod3 = a % 3;
    if (mod3 < 0) mod3 = mod3 + 3;
  endfunction
  
  function [GRID_W-1:0] mod8;
    input signed [3:0] a;
    mod8 = a % 8;
    if (mod8 < 0) mod8 = mod8 + 8;
  endfunction
  
  // Current positions (pre-move) for this cycle
  logic [MAX_PLANETOIDS-1:0][GRID_W-1:0] cur_x, cur_y, cur_z;
  assign cur_x = started_q ? x_q : x_in;
  assign cur_y = started_q ? y_q : y_in;
  assign cur_z = started_q ? z_q : z_in;
  
  // Next positions after moving 1 time unit
  logic [MAX_PLANETOIDS-1:0][GRID_W-1:0] nx, ny, nz;
  logic signed [MAX_PLANETOIDS-1:0][3:0] cvx, cvy, cvz;
  assign cvx = started_q ? vx_q : vx_in;
  assign cvy = started_q ? vy_q : vy_in;
  assign cvz = started_q ? vz_q : vz_in;
  genvar gi;
  generate
    for (gi=0; gi<MAX_PLANETOIDS; gi++) begin : move_pos
      assign nx[gi] = mod8(cur_x[gi] + cvx[gi]);
      assign ny[gi] = mod8(cur_y[gi] + cvy[gi]);
      assign nz[gi] = mod8(cur_z[gi] + cvz[gi]);
    end
  endgenerate
  
  // Collision groups (by next position)
  logic [7:0][7:0][7:0-1:0][MAX_PLANETOIDS-1:0] pos_idx_map; // [x][y][z] -> bitmask of indices at that pos
  integer xi, yi, zi, pi;
  always @* begin
    for (xi=0; xi<8; xi++) begin
      for (yi=0; yi<8; yi++) begin
        for (zi=0; zi<8; zi++) begin
          pos_idx_map[xi][yi][zi] = '0;
        end
      end
    end
    for (pi=0; pi<MAX_PLANETOIDS; pi++) begin
      if (active_q[pi]) begin
        pos_idx_map[nx[pi]][ny[pi]][nz[pi]][pi] = 1'b1;
      end
    end
  end
  
  // Collision detection
  logic any_collision;
  always @* begin
    any_collision = 1'b0;
    for (xi=0; xi<8; xi++) begin
      for (yi=0; yi<8; yi++) begin
        for (zi=0; zi<8; zi++) begin
          if ($countones(pos_idx_map[xi][yi][zi]) > 1) begin
            any_collision = 1'b1;
          end
        end
      end
    end
  end
  
  // Determine survivors per position (lowest index absorbs all at that pos)
  logic [MAX_PLANETOIDS-1:0][GRID_W-1:0] pos_sx, pos_sy, pos_sz;
  logic [MAX_PLANETOIDS-1:0] survivor_of_pos;
  logic [MAX_PLANETOIDS-1:0] kill_mask; // indices to be removed (merged away)
  logic [MAX_PLANETOIDS-1:0] merged_acc; // accumulators by survivor index
  logic [MAX_PLANETOIDS-1:0] merged_valid; // whether accumulator is active for that survivor
  logic [MAX_PLANETOIDS-1:0][8:0] merged_mass;
  logic signed [MAX_PLANETOIDS-1:0][3:0] merged_vx, merged_vy, merged_vz;
  
  always @* begin
    for (pi=0; pi<MAX_PLANETOIDS; pi++) begin
      pos_sx[pi] = nx[pi];
      pos_sy[pi] = ny[pi];
      pos_sz[pi] = nz[pi];
    end
    survivor_of_pos = '0;
    kill_mask = '0;
    merged_acc = '0;
    merged_valid = '0;
    merged_mass = '0;
    merged_vx = '0;
    merged_vy = '0;
    merged_vz = '0;
    
    for (xi=0; xi<8; xi++) begin
      for (yi=0; yi<8; yi++) begin
        for (zi=0; zi<8; zi++) begin
          if ($countones(pos_idx_map[xi][yi][zi]) > 1) begin
            // Find lowest index at this position
            for (pi=0; pi<MAX_PLANETOIDS; pi++) begin
              if (pos_idx_map[xi][yi][zi][pi]) begin
                survivor_of_pos[pi] = 1'b1;
                break;
              end
            end
            // Accumulate into survivor and mark others for removal
            for (pi=0; pi<MAX_PLANETOIDS; pi++) begin
              if (pos_idx_map[xi][yi][zi][pi]) begin
                if (survivor_of_pos[pi]) begin
                  merged_valid[pi] = 1'b1;
                  merged_mass[pi] = merged_mass[pi] + mass_q[pi];
                  merged_vx[pi] = merged_vx[pi] + vx_q[pi];
                  merged_vy[pi] = merged_vy[pi] + vy_q[pi];
                  merged_vz[pi] = merged_vz[pi] + vz_q[pi];
                end else begin
                  kill_mask[pi] = 1'b1;
                end
              end
            end
          end
        end
      end
    end
  end
  
  // Update velocities for merged groups (truncate division)
  logic [MAX_PLANETOIDS-1:0][3:0] nvx, nvy, nvz;
  always @* begin
    nvx = vx_q;
    nvy = vy_q;
    nvz = vz_q;
    for (pi=0; pi<MAX_PLANETOIDS; pi++) begin
      if (merged_valid[pi]) begin
        nvx[pi] = merged_vx[pi] / $countones(pos_idx_map[pos_sx[pi]][pos_sy[pi]][pos_sz[pi]]);
        nvy[pi] = merged_vy[pi] / $countones(pos_idx_map[pos_sx[pi]][pos_sy[pi]][pos_sz[pi]]);
        nvz[pi] = merged_vz[pi] / $countones(pos_idx_map[pos_sx[pi]][pos_sy[pi]][pos_sz[pi]]);
      end
    end
  end
  
  // Next-cycle state (positions and mass update for survivors)
  always @* begin
    active_next = active_q;
    mass_next = mass_q;
    x_next = nx;
    y_next = ny;
    z_next = nz;
    vx_next = nvx;
    vy_next = nvy;
    vz_next = nvz;
    
    if (any_collision) begin
      for (pi=0; pi<MAX_PLANETOIDS; pi++) begin
        if (kill_mask[pi]) begin
          active_next[pi] = 1'b0;
        end
        if (merged_valid[pi]) begin
          mass_next[pi] = merged_mass[pi];
        end
      end
    end
  end
  
  // Control logic
  assign started_next = started_q | start;
  always @* begin
    cycle_next = cycle_q;
    if (!started_q) begin
      cycle_next = '0;
    end else begin
      // Advance cycle either when not started or during run
      if (any_collision && (cycle_q < (MAX_CYCLES-1))) begin
        cycle_next = cycle_q + 1;
      end
    end
  end
  
  // Sequential update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      started_q <= 1'b0;
      cycle_q <= '0;
      active_q <= '0;
      mass_q <= '0;
      x_q <= '0;
      y_q <= '0;
      z_q <= '0;
      vx_q <= '0;
      vy_q <= '0;
      vz_q <= '0;
      last_x_r <= '0;
      last_y_r <= '0;
      last_z_r <= '0;
    end else begin
      started_q <= started_next;
      cycle_q <= cycle_next;
      
      if (!started_q) begin
        // Latch initial values
        active_q <= '1;
        mass_q <= masses_in;
        x_q <= x_in;
        y_q <= y_in;
        z_q <= z_in;
        vx_q <= vx_in;
        vy_q <= vy_in;
        vz_q <= vz_in;
        last_x_r <= x_in;
        last_y_r <= y_in;
        last_z_r <= z_in;
      end else begin
        // Simulation step
        active_q <= active_next;
        mass_q <= mass_next;
        x_q <= x_next;
        y_q <= y_next;
        z_q <= z_next;
        vx_q <= vx_next;
        vy_q <= vy_next;
        vz_q <= vz_next;
        // Save last positions for tie-breaking (use pre-merge current positions)
        last_x_r <= cur_x;
        last_y_r <= cur_y;
        last_z_r <= cur_z;
      end
    end
  end
  
  // Done flag
  assign done = started_q && (!any_collision || (cycle_q == (MAX_CYCLES-1)));
  
  // Build compact list of active planets for sorting and output
  logic [3:0][8:0] act_mass;
  logic [3:0][GRID_W-1:0] act_x, act_y, act_z;
  logic signed [3:0][3:0] act_vx, act_vy, act_vz;
  logic [1:0] act_count;
  
  always @* begin
    act_mass = '0;
    act_x = '0;
    act_y = '0;
    act_z = '0;
    act_vx = '0;
    act_vy = '0;
    act_vz = '0;
    act_count = '0;
    for (pi=0; pi<MAX_PLANETOIDS; pi++) begin
      if (active_q[pi]) begin
        act_mass[act_count] = mass_q[pi];
        act_x[act_count] = x_q[pi];
        act_y[act_count] = y_q[pi];
        act_z[act_count] = z_q[pi];
        act_vx[act_count] = vx_q[pi];
        act_vy[act_count] = vy_q[pi];
        act_vz[act_count] = vz_q[pi];
        act_count = act_count + 1;
      end
    end
  end
  
  // Sort act_* by mass desc, then x asc, y asc, z asc (bubble sort)
  logic [3:0][8:0] s_mass;
  logic [3:0][GRID_W-1:0] s_x, s_y, s_z;
  logic signed [3:0][3:0] s_vx, s_vy, s_vz;
  integer i, j;
  always @* begin
    s_mass = act_mass;
    s_x = act_x;
    s_y = act_y;
    s_z = act_z;
    s_vx = act_vx;
    s_vy = act_vy;
    s_vz = act_vz;
    for (i=0; i<4; i++) begin
      for (j=i+1; j<4; j++) begin
        if ( (s_mass[j] > s_mass[i]) ||
             ((s_mass[j] == s_mass[i]) && (s_x[j] < s_x[i])) ||
             ((s_mass[j] == s_mass[i]) && (s_x[j] == s_x[i]) && (s_y[j] < s_y[i])) ||
             ((s_mass[j] == s_mass[i]) && (s_x[j] == s_x[i]) && (s_y[j] == s_y[i]) && (s_z[j] < s_z[i])) ) begin
          // swap j and i
          s_mass[j] <= s_mass[i];
          s_x[j] <= s_x[i];
          s_y[j] <= s_y[i];
          s_z[j] <= s_z[i];
          s_vx[j] <= s_vx[i];
          s_vy[j] <= s_vy[i];
          s_vz[j] <= s_vz[i];
          s_mass[i] <= act_mass[j];
          s_x[i] <= act_x[j];
          s_y[i] <= act_y[j];
          s_z[i] <= act_z[j];
          s_vx[i] <= act_vx[j];
          s_vy[i] <= act_vy[j];
          s_vz[i] <= act_vz[j];
        end
      end
    end
  end
  
  // Output assignment: P0-P3 IDs assigned by sorted order, pad zeros for inactive
  always @* begin
    planet_count = act_count;
    masses_out = '0;
    x_out = '0;
    y_out = '0;
    z_out = '0;
    vx_out = '0;
    vy_out = '0;
    vz_out = '0;
    if (act_count > 0) begin
      masses_out[0] = s_mass[0];
      x_out[0] = s_x[0];
      y_out[0] = s_y[0];
      z_out[0] = s_z[0];
      vx_out[0] = s_vx[0];
      vy_out[0] = s_vy[0];
      vz_out[0] = s_vz[0];
    end
    if (act_count > 1) begin
      masses_out[1] = s_mass[1];
      x_out[1] = s_x[1];
      y_out[1] = s_y[1];
      z_out[1] = s_z[1];
      vx_out[1] = s_vx[1];
      vy_out[1] = s_vy[1];
      vz_out[1] = s_vz[1];
    end
    if (act_count > 2) begin
      masses_out[2] = s_mass[2];
      x_out[2] = s_x[2];
      y_out[2] = s_y[2];
      z_out[2] = s_z[2];
      vx_out[2] = s_vx[2];
      vy_out[2] = s_vy[2];
      vz_out[2] = s_vz[2];
    end
    if (act_count > 3) begin
      masses_out[3] = s_mass[3];
      x_out[3] = s_x[3];
      y_out[3] = s_y[3];
      z_out[3] = s_z[3];
      vx_out[3] = s_vx[3];
      vy_out[3] = s_vy[3];
      vz_out[3] = s_vz[3];
    end
  end
  
endmodule