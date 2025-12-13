module planet_collision_sim(
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

  // Parameters
  localparam int MAX_CYCLES      = 8;
  localparam int MAX_PLANETOIDS  = 4;

  // State encoding
  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_INIT   = 3'd1,
    S_STEP   = 3'd2,
    S_CHECK  = 3'd3,
    S_SORT   = 3'd4,
    S_DONE   = 3'd5
  } state_t;

  state_t state, next_state;

  // Internal storage for planetoids
  reg [8:0]  mass    [0:MAX_PLANETOIDS-1];
  reg [2:0]  pos_x   [0:MAX_PLANETOIDS-1];
  reg [2:0]  pos_y   [0:MAX_PLANETOIDS-1];
  reg [2:0]  pos_z   [0:MAX_PLANETOIDS-1];
  reg [3:0]  vel_x   [0:MAX_PLANETOIDS-1];
  reg [3:0]  vel_y   [0:MAX_PLANETOIDS-1];
  reg [3:0]  vel_z   [0:MAX_PLANETOIDS-1];
  reg        active  [0:MAX_PLANETOIDS-1];

  // Next state of planetoids
  reg [8:0]  n_mass    [0:MAX_PLANETOIDS-1];
  reg [2:0]  n_pos_x   [0:MAX_PLANETOIDS-1];
  reg [2:0]  n_pos_y   [0:MAX_PLANETOIDS-1];
  reg [2:0]  n_pos_z   [0:MAX_PLANETOIDS-1];
  reg [3:0]  n_vel_x   [0:MAX_PLANETOIDS-1];
  reg [3:0]  n_vel_y   [0:MAX_PLANETOIDS-1];
  reg [3:0]  n_vel_z   [0:MAX_PLANETOIDS-1];
  reg        n_active  [0:MAX_PLANETOIDS-1];

  // Cycle counter and done flag
  reg [3:0] cycle_cnt;
  reg       collisions_exist;

  // Helpers
  integer i, j;

  // Signed velocity arithmetic helpers (internal wires)
  function automatic [2:0] mod8_add_3(
    input [2:0] pos,
    input [3:0] vel
  );
    // vel is 4-bit signed (-8..7). We only need mod-8 of total.
    // Compute pos + vel, then wrap to 0-7.
    integer tmp;
    begin
      tmp = $signed(vel) + pos;
      // Wrap into [0,7]
      // Using repeated adjustments to avoid % on negative
      while (tmp < 0) tmp = tmp + 8;
      while (tmp > 7) tmp = tmp - 8;
      mod8_add_3 = tmp[2:0];
    end
  endfunction

  // Average velocity with truncation toward zero
  function automatic [3:0] avg_vel(
    input integer sum,
    input integer count
  );
    integer q;
    begin
      if (sum >= 0)
        q = sum / count;
      else
        q = -((-sum) / count);
      // q is in reasonable range; fit into 4-bit signed
      avg_vel = $signed(q[3:0]);
    end
  endfunction

  // Count active bodies
  function automatic [1:0] count_active;
    integer k;
    reg [2:0] c;
    begin
      c = 0;
      for (k = 0; k < MAX_PLANETOIDS; k = k + 1) begin
        if (active[k]) c = c + 1;
      end
      count_active = c[1:0];
    end
  endfunction

  // Next-state combinational logic for FSM and simulation
  always @* begin
    // Default
    next_state        = state;
    collisions_exist  = 1'b0;

    // Default next values: hold
    for (i = 0; i < MAX_PLANETOIDS; i = i + 1) begin
      n_mass[i]   = mass[i];
      n_pos_x[i]  = pos_x[i];
      n_pos_y[i]  = pos_y[i];
      n_pos_z[i]  = pos_z[i];
      n_vel_x[i]  = vel_x[i];
      n_vel_y[i]  = vel_y[i];
      n_vel_z[i]  = vel_z[i];
      n_active[i] = active[i];
    end

    case (state)
      S_IDLE: begin
        if (start) begin
          next_state = S_INIT;
        end
      end

      S_INIT: begin
        // After registers load in seq always, go to STEP
        next_state = S_STEP;
      end

      S_STEP: begin
        // Advance positions for all active bodies
        for (i = 0; i < MAX_PLANETOIDS; i = i + 1) begin
          if (active[i]) begin
            n_pos_x[i] = mod8_add_3(pos_x[i], vel_x[i]);
            n_pos_y[i] = mod8_add_3(pos_y[i], vel_y[i]);
            n_pos_z[i] = mod8_add_3(pos_z[i], vel_z[i]);
          end
        end
        next_state = S_CHECK;
      end

      S_CHECK: begin
        // Perform collision detection and merging on updated positions
        // Start from current (already in n_* from STEP)
        // We'll operate on temp arrays coll_* to avoid repeated alias confusion
        reg [8:0]  coll_mass   [0:MAX_PLANETOIDS-1];
        reg [2:0]  coll_x      [0:MAX_PLANETOIDS-1];
        reg [2:0]  coll_y      [0:MAX_PLANETOIDS-1];
        reg [2:0]  coll_z      [0:MAX_PLANETOIDS-1];
        reg [3:0]  coll_vx     [0:MAX_PLANETOIDS-1];
        reg [3:0]  coll_vy     [0:MAX_PLANETOIDS-1];
        reg [3:0]  coll_vz     [0:MAX_PLANETOIDS-1];
        reg        coll_active [0:MAX_PLANETOIDS-1];

        integer s_mass_x, s_mass_y, s_mass_z;
        integer sum_vx, sum_vy, sum_vz;
        integer cnt;

        // Initialize temp arrays from n_* (positions after move)
        for (i = 0; i < MAX_PLANETOIDS; i = i + 1) begin
          coll_mass[i]   = n_mass[i];
          coll_x[i]      = n_pos_x[i];
          coll_y[i]      = n_pos_y[i];
          coll_z[i]      = n_pos_z[i];
          coll_vx[i]     = n_vel_x[i];
          coll_vy[i]     = n_vel_y[i];
          coll_vz[i]     = n_vel_z[i];
          coll_active[i] = n_active[i];
        end

        // Collision resolution: lowest index absorbs
        for (i = 0; i < MAX_PLANETOIDS; i = i + 1) begin
          if (coll_active[i]) begin
            // Check if others share same position
            cnt    = 1;
            sum_vx = $signed(coll_vx[i]);
            sum_vy = $signed(coll_vy[i]);
            sum_vz = $signed(coll_vz[i]);
            for (j = i + 1; j < MAX_PLANETOIDS; j = j + 1) begin
              if (coll_active[j] &&
                  coll_x[j] == coll_x[i] &&
                  coll_y[j] == coll_y[i] &&
                  coll_z[j] == coll_z[i]) begin
                // Merge j into i
                collisions_exist   = 1'b1;
                coll_mass[i]       = coll_mass[i] + coll_mass[j];
                sum_vx             = sum_vx + $signed(coll_vx[j]);
                sum_vy             = sum_vy + $signed(coll_vy[j]);
                sum_vz             = sum_vz + $signed(coll_vz[j]);
                coll_active[j]     = 1'b0; // removed
                cnt                = cnt + 1;
              end
            end
            // If any merges occurred (cnt>1), update velocity of i to avg
            if (cnt > 1) begin
              coll_vx[i] = avg_vel(sum_vx, cnt);
              coll_vy[i] = avg_vel(sum_vy, cnt);
              coll_vz[i] = avg_vel(sum_vz, cnt);
            end
          end
        end

        // Write back to n_* arrays
        for (i = 0; i < MAX_PLANETOIDS; i = i + 1) begin
          n_mass[i]   = coll_mass[i];
          n_pos_x[i]  = coll_x[i];
          n_pos_y[i]  = coll_y[i];
          n_pos_z[i]  = coll_z[i];
          n_vel_x[i]  = coll_vx[i];
          n_vel_y[i]  = coll_vy[i];
          n_vel_z[i]  = coll_vz[i];
          n_active[i] = coll_active[i];
        end

        // Determine next state based on collisions and cycles
        if (!collisions_exist && (cycle_cnt >= MAX_CYCLES)) begin
          next_state = S_SORT;
        end else if (!collisions_exist && (cycle_cnt < MAX_CYCLES)) begin
          next_state = S_STEP;
        end else if (collisions_exist && (cycle_cnt >= MAX_CYCLES)) begin
          // collisions on last cycle; still finish then sort
          next_state = S_SORT;
        end else begin
          // collisions_exist && cycle_cnt < MAX_CYCLES -> continue
          next_state = S_STEP;
        end
      end

      S_SORT: begin
        // Sorting done in sequential always using a small FSM span;
        // here we immediately go to DONE; combinationally next_state = S_DONE,
        // actual data movement done in seq block.
        next_state = S_DONE;
      end

      S_DONE: begin
        // Wait here until reset
        next_state = S_DONE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      cycle_cnt   <= 4'd0;
      done        <= 1'b0;
      planet_count <= 2'd0;

      for (i = 0; i < MAX_PLANETOIDS; i = i + 1) begin
        mass[i]      <= 9'd0;
        pos_x[i]     <= 3'd0;
        pos_y[i]     <= 3'd0;
        pos_z[i]     <= 3'd0;
        vel_x[i]     <= 4'd0;
        vel_y[i]     <= 4'd0;
        vel_z[i]     <= 4'd0;
        active[i]    <= 1'b0;

        masses_out[i] <= 9'd0;
        x_out[i]      <= 3'd0;
        y_out[i]      <= 3'd0;
        z_out[i]      <= 3'd0;
        vx_out[i]     <= 4'd0;
        vy_out[i]     <= 4'd0;
        vz_out[i]     <= 4'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done        <= 1'b0;
          planet_count <= 2'd0;
          cycle_cnt   <= 4'd0;
          // Wait for start; no changes otherwise
        end

        S_INIT: begin
          // Latch initial values
          for (i = 0; i < MAX_PLANETOIDS; i = i + 1) begin
            mass[i]   <= masses_in[i];
            pos_x[i]  <= x_in[i];
            pos_y[i]  <= y_in[i];
            pos_z[i]  <= z_in[i];
            vel_x[i]  <= vx_in[i];
            vel_y[i]  <= vy_in[i];
            vel_z[i]  <= vz_in[i];
            active[i] <= 1'b1;
          end
          cycle_cnt <= 4'd0;
          done      <= 1'b0;
        end

        S_STEP: begin
          // Apply movement (from n_* computed in combinational)
          for (i = 0; i < MAX_PLANETOIDS; i = i + 1) begin
            mass[i]   <= n_mass[i];
            pos_x[i]  <= n_pos_x[i];
            pos_y[i]  <= n_pos_y[i];
            pos_z[i]  <= n_pos_z[i];
            vel_x[i]  <= n_vel_x[i];
            vel_y[i]  <= n_vel_y[i];
            vel_z[i]  <= n_vel_z[i];
            active[i] <= n_active[i];
          end

          if (cycle_cnt < 4'd15)
            cycle_cnt <= cycle_cnt + 1'b1;
          done <= 1'b0;
        end

        S_CHECK: begin
          // Apply post-collision state from n_*
          for (i = 0; i < MAX_PLANETOIDS; i = i + 1) begin
            mass[i]   <= n_mass[i];
            pos_x[i]  <= n_pos_x[i];
            pos_y[i]  <= n_pos_y[i];
            pos_z[i]  <= n_pos_z[i];
            vel_x[i]  <= n_vel_x[i];
            vel_y[i]  <= n_vel_y[i];
            vel_z[i]  <= n_vel_z[i];
            active[i] <= n_active[i];
          end
          done <= 1'b0;
        end

        S_SORT: begin
          // Prepare an index array and sort indices by rules
          integer a, b;
          reg [1:0] idx [0:MAX_PLANETOIDS-1];
          reg [1:0] tmp_idx;

          // Initialize indices
          for (a = 0; a < MAX_PLANETOIDS; a = a + 1) begin
            idx[a] = a[1:0];
          end

          // Simple bubble sort on indices
          // Priority: active first (mass>0), then mass desc, then x,y,z asc
          for (a = 0; a < MAX_PLANETOIDS; a = a + 1) begin
            for (b = 0; b < MAX_PLANETOIDS-1; b = b + 1) begin
              integer i0, i1;
              reg swap;
              i0 = idx[b];
              i1 = idx[b+1];
              swap = 1'b0;

              // Define keys
              // active: 1 if active, 0 if not; we want active first
              if (active[i0] && !active[i1]) begin
                // keep
                swap = 1'b0;
              end else if (!active[i0] && active[i1]) begin
                swap = 1'b1;
              end else if (active[i0] == active[i1]) begin
                // If both same active state
                if (active[i0]) begin
                  // Both active: compare mass desc
                  if (mass[i0] < mass[i1]) begin
                    swap = 1'b1;
                  end else if (mass[i0] == mass[i1]) begin
                    // tie-breaker: x asc, then y asc, then z asc
                    if (pos_x[i0] > pos_x[i1]) begin
                      swap = 1'b1;
                    end else if (pos_x[i0] == pos_x[i1]) begin
                      if (pos_y[i0] > pos_y[i1]) begin
                        swap = 1'b1;
                      end else if (pos_y[i0] == pos_y[i1]) begin
                        if (pos_z[i0] > pos_z[i1]) begin
                          swap = 1'b1;
                        end
                      end
                    end
                  end
                end else begin
                  // both inactive: keep order (no preference)
                  swap = 1'b0;
                end
              end

              if (swap) begin
                tmp_idx    = idx[b];
                idx[b]     = idx[b+1];
                idx[b+1]   = tmp_idx;
              end
            end
          end

          // Drive outputs in sorted order (P0..P3 are sorted)
          for (a = 0; a < MAX_PLANETOIDS; a = a + 1) begin
            if (active[idx[a]]) begin
              masses_out[a] <= mass[idx[a]];
              x_out[a]      <= pos_x[idx[a]];
              y_out[a]      <= pos_y[idx[a]];
              z_out[a]      <= pos_z[idx[a]];
              vx_out[a]     <= vel_x[idx[a]];
              vy_out[a]     <= vel_y[idx[a]];
              vz_out[a]     <= vel_z[idx[a]];
            end else begin
              masses_out[a] <= 9'd0;
              x_out[a]      <= 3'd0;
              y_out[a]      <= 3'd0;
              z_out[a]      <= 3'd0;
              vx_out[a]     <= 4'd0;
              vy_out[a]     <= 4'd0;
              vz_out[a]     <= 4'd0;
            end
          end

          // Planet count
          planet_count <= count_active();

          done <= 1'b0; // done will be set in S_DONE
        end

        S_DONE: begin
          // Hold outputs and signal done
          done <= 1'b1;
        end

        default: begin
          // Safety
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule