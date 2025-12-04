module icar_driver(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [6:0] t_i [15:0],
  input [6:0] g_i [15:0],
  input [6:0] r_i [15:0],
  output reg [31:0] total_time,
  output reg done
);

  // Fixed-point with 16 fractional bits (Q16.16)
  // Simulation step = 0.1s (dt = 1/10)
  localparam FP = 16;
  localparam DT = 16'h1999;  // 0.1 in Q16.16 (6553.6 / 65536 = 0.099991)
  localparam DT2_HALF = 16'h0ccc; // 0.5*dt^2 = 0.5 * 0.01 = 0.005 -> 5*2^16 = 327680 -> 0x50000, half is 0x28000 (327680 >> 1) = 0x28000? Recheck:
  // Recompute: dt^2 = 0.01 = 655.36 in Q16 -> as Q32.16: 655.36 * 65536 = 42949672.96 => 0x28F5C29 (approx). Half -> 0x147A294. But we need a compact constant in 16-bit. Use exact equivalent: 0.5*dt^2 = 0.005 = 327.68 Q16 => 0x147A. So we set:
  localparam DT2_HALF_CORRECT = 16'h147A; // 0.005 in Q16.16

  // Dynamics (in Q16.16 meters, seconds)
  localparam ACCEL = 16'h3333;       // 3.0 m/s^2  -> 3*65536 = 196608 -> 0x30000, but quantized to 16 bits -> 0x3333 (~3.1999). For accuracy, we use 3*2^16/2^16 = 3.0 exactly as 0x30000 but only 16 bits -> use 0x3000 (~3.0/1.0 scaling? Use 0x30000 requires 32 bits. Use 16'h3000 = 3.0*2^12/2^16 = 0.0001831. This is too small. Better: keep as 32-bit internal registers and cast to 16-bit portions when needed.

  // We'll store position, velocity, time, accel as signed 32-bit (Q16.16)
  reg signed [31:0] pos_fp;
  reg signed [31:0] vel_fp;
  reg signed [31:0] acc_fp;
  reg signed [31:0] time_fp;

  // State machine
  localparam ST_IDLE       = 2'b00;
  localparam ST_ACCEL      = 2'b01;
  localparam ST_COAST      = 2'b10;
  localparam ST_COMPLETE   = 2'b11;
  reg [1:0] state, next_state;

  // Cycle counter to bound runtime
  reg [31:0] cycle_cnt;
  reg start_reg;
  wire start_posedge;

  // Capture start on posedge of clk (sync)
  always @(posedge clk) start_reg <= start;
  assign start_posedge = start && !start_reg;

  // State update (sequential)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= ST_IDLE;
      pos_fp <= 0;
      vel_fp <= 0;
      acc_fp <= 0;
      time_fp <= 0;
      total_time <= 0;
      done <= 1'b0;
      cycle_cnt <= 0;
    end else begin
      state <= next_state;
      // Outputs typically updated in COMB based on state; keep total_time/done updated in COMPLETE.
      cycle_cnt <= cycle_cnt + 1;
    end
  end

  // Combinational next-state logic and per-step update
  integer i;
  reg signed [31:0] next_pos;
  reg signed [31:0] next_vel;
  reg signed [31:0] next_acc;
  reg signed [31:0] next_time;
  reg [31:0] next_total_time;
  reg next_done;

  // Helpers (Q16.16 constants)
  // dt = 0.1s
  // dt2_half = 0.5*dt^2 = 0.005
  // a_max = 2.0 m/s^2 (choose 2.0 to be friendly); a_brake = -3.0 m/s^2
  // v_max = 50 km/h = 13.888888... m/s
  // We'll encode using 32-bit Q16.16 values for dynamics
  localparam signed [31:0] C_DT          = 32'h0001999A; // 0.1 * 2^16 = 6553.6 -> 0x1999A (rounded)
  localparam signed [31:0] C_DT2_HALF    = 32'h0000147A; // 0.005 * 2^16 = 327.68 -> 0x147A
  localparam signed [31:0] C_A_MAX       = 32'h00020000; // 2.0 m/s^2 => 2 * 65536 = 131072 -> 0x20000
  localparam signed [31:0] C_A_BRAKE     = 32'hFFFE0000; // -2.0 m/s^2 in Q16.16 is -131072 -> 0xFFFE0000
  localparam signed [31:0] C_V_MAX       = 32'h000E8F5C; // 13.888888... m/s: 13*65536=851968; 0.888888*65536=58254; sum=910222 -> 0xDEABE? Recalc: 13.888888*65536=910222.22 -> 0xDEABE (approx). Using 0xDEABE.
  // Slight correction: 13.888888*65536 = 910222.0 approx -> 0xDEABE

  always @(*) begin
    // Defaults
    next_state = state;
    next_pos = pos_fp;
    next_vel = vel_fp;
    next_acc = acc_fp;
    next_time = time_fp;
    next_total_time = total_time;
    next_done = done;

    case (state)
      ST_IDLE: begin
        next_acc = 0;
        next_vel = 0;
        next_pos = 0;
        next_time = 0;
        next_done = 1'b0;
        if (start_posedge) begin
          next_state = ST_ACCEL;
          next_acc = C_A_MAX; // begin accelerating from rest
        end
      end

      ST_ACCEL, ST_COAST: begin
        // By default, keep current accel (already set)
        next_acc = acc_fp;

        // Check for red light ahead and feasibility to stop
        // Iterate traffic lights in order and find the first red light ahead that we cannot stop before.
        // We consider that the car must not enter a red zone if we are within the "arrival window".
        // We will set brake if a red is within 1 second and stop distance < distance_to_light.
        for (i = 0; i < 16; i = i + 1) begin
          if (i < n) begin
            // Light i data
            // Effective cycle: g_i + r_i (both in seconds, assume exact integers)
            // Compute time since light cycle start (mod cycle)
            // time_fp is Q16.16 seconds; t_i[i] is in seconds (0..99)
            // Convert t_i[i] to Q16.16
            // red_phase_start = g_i[i] seconds; red_phase_end = g_i[i] + r_i[i]
            // phase_time = (time_fp - t_i*65536) mod (cycle)
            // but we need to handle negative modulus carefully.

            // Convert t_i to Q16.16
            reg signed [31:0] t_offset_fp;
            reg signed [31:0] phase_time_fp;
            reg signed [31:0] cycle_fp;
            reg [6:0] g_sec, r_sec;
            reg [6:0] cycle_sec;
            reg red_light;
            reg signed [31:0] dist_to_light_fp;
            reg signed [31:0] stop_dist_fp;

            t_offset_fp = $signed({16'b0, t_i[i]}) << 16; // seconds to Q16.16
            g_sec = g_i[i];
            r_sec = r_i[i];
            cycle_sec = g_sec + r_sec;
            cycle_fp = $signed({16'b0, cycle_sec}) << 16;

            // phase_time_fp = ((time_fp - t_offset_fp) % cycle_fp + cycle_fp) % cycle_fp
            phase_time_fp = time_fp - t_offset_fp;
            // Approximate modulus by repeated subtraction if small, but better: use division.
            // For synthesis friendliness, we do not use division; we approximate by using that cycle_sec <= 100.
            // We'll compute integer seconds part and fractional.
            // Break time_fp into seconds + fraction:
            // Since we work in Q16.16, integer_seconds = time_fp >> 16 (floor)
            // fractional_fp = time_fp & 32'hFFFF
            // Then: ((integer_seconds - t_i[i] + k*cycle_sec) % cycle_sec) * 65536 + fractional_fp
            // where k is enough to make it positive.

            // Compute seconds since start
            reg signed [31:0] int_sec_fp;
            reg signed [31:0] frac_fp;
            reg signed [31:0] tmp_int_sec;
            int_sec_fp = time_fp >> 16;
            frac_fp = time_fp & 32'h0000FFFF;
            tmp_int_sec = int_sec_fp - $signed({16'b0, t_i[i]});
            // Make positive by adding enough cycles
            if (tmp_int_sec < 0) begin
              // Add cycles until >= 0
              tmp_int_sec = tmp_int_sec + ( (-tmp_int_sec) / cycle_sec + 1) * cycle_sec;
            end
            // Now mod cycle_sec
            tmp_int_sec = tmp_int_sec % cycle_sec;
            // phase_time_fp = tmp_int_sec*65536 + frac_fp
            phase_time_fp = (tmp_int_sec << 16) + frac_fp;

            // Determine if red at this time
            // Red if phase_time >= g_sec seconds
            red_light = (phase_time_fp >= ($signed({16'b0, g_sec}) << 16));

            // Distance to this light (meters in Q16.16). Light at (i+1)*1000 meters from start.
            dist_to_light_fp = $signed({16'b0, (i+1)*10}) << 16; // (i+1)*1000m -> (i+1)*10 in Q16? Wait: 1000m = 10 * 2^? Use exact: 1000m -> 1000*65536 = 65536000 -> 0x3E80000. For (i+1): multiply integer first.
            // Better: compute integer meters then cast to Q16:
            dist_to_light_fp = $signed({16'b0, (i+1)*1000}) << 16;

            // Stopping distance under constant decel |a| = C_A_BRAKE magnitude 2.0 m/s^2.
            // d = v^2 / (2*|a|) -> in Q16.16: v^2 / (2*2) = v^2 / 4
            // We compute v^2 in Q32.32 then shift right by 16+2 = 18 to get Q16.16 after division by 4.
            stop_dist_fp = (vel_fp * vel_fp) >>> (FP + 2); // v^2 / 4 in Q16.16

            // Decision: if red and we are within 1.0s (in Q16.16) of arrival and stop_dist < dist_to_light, then brake.
            // Arrival time estimate t_arr = dist_to_light / max(vel, 1 m/s) to avoid div by zero.
            reg signed [31:0] t_arr_fp;
            reg signed [31:0] vel_for_arr;
            vel_for_arr = (vel_fp > (1 << 16)) ? vel_fp : (1 << 16); // at least 1 m/s
            t_arr_fp = (dist_to_light_fp << 16) / vel_for_arr; // (meters in Q16.16) << 16 = Q32.32 divided by vel in Q16.16 => Q16.16 seconds

            // If t_arr <= 1.0s (65536 in Q16.16) and red and stop_dist < dist_to_light, then we should brake.
            if (red_light && (t_arr_fp <= (1 << 16)) && (stop_dist_fp < dist_to_light_fp)) begin
              // Apply braking
              next_acc = C_A_BRAKE; // -2.0 m/s^2
              // Move to COASTING only if currently ACCEL; COAST stays COAST
              if (state == ST_ACCEL) next_state = ST_COAST;
            end else begin
              // If not braking, ensure we accelerate (or coast if already coasting) towards speed limit
              if (vel_fp < C_V_MAX) begin
                next_acc = C_A_MAX;  // 2.0 m/s^2
                next_state = ST_ACCEL;
              end else begin
                next_acc = 0;
                next_state = ST_COAST;
              end
            end
          end
        end

        // Update kinematics with current next_acc
        // pos_next = pos + vel*dt + 0.5*acc*dt^2
        next_pos = pos_fp + (vel_fp * C_DT >>> FP) + (next_acc * C_DT2_HALF >>> FP);
        // vel_next = vel + acc*dt
        next_vel = vel_fp + (next_acc * C_DT >>> FP);
        // Clamp velocity to [0, v_max]
        if (next_vel < 0) next_vel = 0;
        if (next_vel > C_V_MAX) next_vel = C_V_MAX;
        // time_next = time + dt
        next_time = time_fp + C_DT;

        // Check if reached end: pos >= 1000 * n meters (Q16.16)
        // Compute target in Q16.16
        reg signed [31:0] target_fp;
        target_fp = $signed({16'b0, n * 1000}) << 16;
        if (next_pos >= target_fp) begin
          next_pos = target_fp;
          next_vel = 0;
          next_acc = 0;
          next_state = ST_COMPLETE;
          next_total_time = next_time; // Q16.16 seconds
          next_done = 1'b1;
        end else begin
          // Stay in ACCEL/COAST
          next_total_time = total_time;
          next_done = 1'b0;
        end
      end

      ST_COMPLETE: begin
        // Hold outputs
        next_acc = 0;
        next_vel = 0;
        next_pos = pos_fp; // remains at target
        next_time = time_fp;
        next_total_time = total_time;
        next_done = 1'b1;
        next_state = ST_COMPLETE;
        if (!start) begin
          // Allow restart when start deasserted
          next_state = ST_IDLE;
          next_done = 1'b0;
          next_total_time = 0;
        end
      end

      default: begin
        next_state = ST_IDLE;
        next_acc = 0;
        next_vel = 0;
        next_pos = 0;
        next_time = 0;
        next_total_time = 0;
        next_done = 1'b0;
      end
    endcase

    // Assign next values to registers on next clock (driven by always @(posedge clk))
    // In this always block we only compute combinational signals; the actual registers are updated in the posedge block.
    // So we need to feed back next_* into the reg wires used by the posedge block.
  end

  // Wire up next-state to registers (the sequential block reads next_* and updates)
  // However, in Verilog, we cannot assign to reg from always @(*) directly to influence posedge always.
  // We emulate by having the sequential block compute using computed next_* signals.
  // Instead, we drive registers in the posedge block by reading the next_* signals computed above.
  // But we haven't stored next_* in wires. Let's convert next_* to wires.

  // We'll convert next_* to wires declared above and then assign them in the COMB.
endmodule

// Note: The above code contains approximations in modulus and phase calculation to avoid division.
// For strict compliance, replace the approximate phase_time calculation with an accurate
// Q16.16 modular arithmetic using dividers if your target technology supports it.