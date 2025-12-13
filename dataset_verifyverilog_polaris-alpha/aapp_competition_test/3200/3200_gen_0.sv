module icar_driver(
  input        clk,
  input        rst_n,
  input        start,
  input  [3:0] n,                 // road length in km (1-16)
  input  [6:0] t_i [15:0],        // initial green time offset (0-99 s)
  input  [6:0] g_i [15:0],        // green duration (40-50 s)
  input  [6:0] r_i [15:0],        // red duration (40-50 s)
  output reg [31:0] total_time,   // Q16.16 format (lower 16 bits fractional)
  output reg       done
);

  // Fixed-point format: Q16.16
  // dt = 0.1 s = 0.1 * 2^16 = 6553.6 -> 16'h199A (approx)
  localparam [31:0] DT_Q16_16   = 32'd6554;      // 0.1 s step
  // (0.5 * dt^2) factor in Q16.16: 0.5*(0.1^2)=0.005 -> *65536=327.68 -> 328
  localparam [31:0] HALF_DT2_Q16_16 = 32'd328;  // 0.5 * dt^2

  // Car behavior constants (arbitrary, consistent units):
  // Use acceleration = 1 m/s^2 in Q16.16 when accelerating, 0 when coasting.
  localparam [31:0] ACCEL_VAL = 32'd65536;  // 1.0 in Q16.16

  // Position in meters, Q16.16
  reg [31:0] pos_q16;
  // Velocity in m/s, Q16.16
  reg [31:0] vel_q16;
  // Acceleration in m/s^2, Q16.16
  reg [31:0] acc_q16;
  // Time in seconds, Q16.16
  reg [31:0] time_q16;

  // Light index we are approaching / checking
  reg [3:0]  light_idx;

  // FSM states
  typedef enum logic [1:0] {
    IDLE         = 2'b00,
    ACCELERATING = 2'b01,
    COASTING     = 2'b10,
    COMPLETE     = 2'b11
  } state_t;

  state_t state, next_state;

  // Internal wires/regs
  reg [31:0] pos_next;
  reg [31:0] vel_next;
  reg [31:0] acc_next;
  reg [31:0] time_next;

  // Light / braking signals
  reg        need_brake;
  reg        passed_all;

  // Combinational: compute next state and motion update
  always @* begin
    // Defaults: hold previous values
    next_state = state;
    pos_next   = pos_q16;
    vel_next   = vel_q16;
    acc_next   = acc_q16;
    time_next  = time_q16;
    need_brake = 1'b0;
    passed_all = 1'b0;

    // Terminal position (in meters, Q16.16): 1000 * n
    // 1000 in Q16.16 is (1000 << 16)
    // We'll compare pos_q16 >= (n * 1000) << 16
    // Use 32-bit multiply; n max 16, safe in 32 bits.
    // Compute target_pos once combinationally
    // (do inline since we cannot define localparams with n)
    // target_pos_q16 = (n * 1000) << 16
    // Evaluate end condition
    if (pos_q16 >= ({12'd0, n} * 32'd1000) << 16) begin
      passed_all  = 1'b1;
      next_state  = COMPLETE;
    end

    if (state == IDLE) begin
      if (start) begin
        // Initialize motion
        pos_next   = 32'd0;
        vel_next   = 32'd0;
        acc_next   = ACCEL_VAL;
        time_next  = 32'd0;
        next_state = ACCELERATING;
      end
    end
    else if (state == ACCELERATING || state == COASTING) begin
      if (!passed_all) begin
        // Time advance
        time_next = time_q16 + DT_Q16_16;

        // Motion update:
        // pos_next = pos + vel*dt + 0.5*acc*dt^2
        // vel_next = vel + acc*dt
        // All in Q16.16: use 64-bit intermediates
        // vel*dt >>16, acc*dt >>16, acc*HALF_DT2 >>16
        // Note: use current vel_q16/acc_q16 for integration

        // velocity increment
        begin : vel_update
          reg [63:0] mul_v;
          mul_v     = vel_q16 + ((acc_q16 * DT_Q16_16) >>> 16);
          vel_next  = mul_v[31:0];
        end

        begin : pos_update
          reg [63:0] term_vdt;
          reg [63:0] term_adt2;
          reg [63:0] sum_pos;
          term_vdt   = (vel_q16 * DT_Q16_16) >>> 16;
          term_adt2  = (acc_q16 * HALF_DT2_Q16_16) >>> 16;
          sum_pos    = pos_q16 + term_vdt + term_adt2;
          pos_next   = sum_pos[31:0];
        end

        // Decide if we must brake due to upcoming red light
        // For simplicity, check the light at each integer km boundary
        // If the car is about to cross or has just crossed a boundary in this step,
        // ensure that crossing time is during green; if red, set need_brake.
        // Light i at position (i+1)*1000 m (i=0..n-1)

        need_brake = 1'b0;

        // Scan all relevant lights (0..n-1)
        begin : check_lights
          integer i;
          for (i = 0; i < 16; i = i + 1) begin
            if (i < n) begin
              // Light position in Q16.16
              reg [31:0] light_pos_q16;
              light_pos_q16 = ((i+1) * 32'd1000) << 16;

              // Check if we are crossing this light in this step
              if ((pos_q16 < light_pos_q16) && (pos_next >= light_pos_q16)) begin
                // Determine signal state at crossing time ~ time_next
                // All times are in seconds; t_i/g_i/r_i in seconds as integers.
                reg [31:0] t_s;
                reg [31:0] g_s;
                reg [31:0] r_s;
                reg [31:0] cyc_s;
                reg [31:0] now_s;
                reg [31:0] rel_s;

                t_s  = {25'd0, t_i[i]};
                g_s  = {25'd0, g_i[i]};
                r_s  = {25'd0, r_i[i]};
                cyc_s = g_s + r_s;

                // Convert Q16.16 time_next to integer seconds (floor)
                now_s = time_next[31:16];

                if (now_s < t_s) begin
                  // Before initial green starts => red
                  need_brake = 1'b1;
                end else begin
                  // Inside cycling region
                  rel_s = now_s - t_s;
                  if (cyc_s != 0) begin
                    reg [31:0] phase;
                    phase = rel_s % cyc_s;
                    if (phase >= g_s) begin
                      // In red interval
                      need_brake = 1'b1;
                    end
                  end else begin
                    // Degenerate, treat as red
                    need_brake = 1'b1;
                  end
                end
              end
            end
          end
        end

        // Acceleration control based on need_brake
        if (need_brake) begin
          // Brake / hold speed: set acc = 0, go to COASTING
          acc_next   = 32'd0;
          next_state = COASTING;
        end else begin
          // If currently coasting and safe (no red), remain coasting (acc=0)
          // If accelerating and no need_brake, keep accelerating
          if (state == ACCELERATING) begin
            acc_next = ACCEL_VAL;
          end else begin
            acc_next = 32'd0;
          end
          // If we had previously coasted and are again safe, we could choose to
          // re-accelerate, but spec: "hold acceler=0 when released" => stay COASTING.
          if (state == COASTING)
            next_state = COASTING;
          else
            next_state = ACCELERATING;
        end

        // Check completion after motion update
        if (pos_next >= ({12'd0, n} * 32'd1000) << 16) begin
          next_state = COMPLETE;
        end
      end
    end
    else if (state == COMPLETE) begin
      // Hold values; done handled in sequential block
      next_state = COMPLETE;
    end
  end

  // Sequential block
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      pos_q16    <= 32'd0;
      vel_q16    <= 32'd0;
      acc_q16    <= 32'd0;
      time_q16   <= 32'd0;
      total_time <= 32'd0;
      done       <= 1'b0;
      light_idx  <= 4'd0;
    end else begin
      state    <= next_state;
      pos_q16  <= pos_next;
      vel_q16  <= vel_next;
      acc_q16  <= acc_next;
      time_q16 <= time_next;

      case (next_state)
        IDLE: begin
          done       <= 1'b0;
          total_time <= 32'd0;
        end
        COMPLETE: begin
          done       <= 1'b1;
          total_time <= time_q16; // expose final Q16.16 time
        end
        default: begin
          done       <= 1'b0;
          total_time <= 32'd0;
        end
      endcase
    end
  end

endmodule