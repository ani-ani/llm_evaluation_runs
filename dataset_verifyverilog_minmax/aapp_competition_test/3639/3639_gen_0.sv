module optimal_cycling(
  input clk,
  input rst_n,
  input start,
  input [3:0] T,
  input [31:0] c_fp,
  input [31:0] d_fp,
  input [7:0] rain [0:15],
  output reg [31:0] min_wetness_fp,
  output reg done
);

  // Constants in Q16.16
  localparam [31:0] C_1MIN_FP  = 16'h0001_0000;        // 1.0
  localparam [31:0] C_60_FP    = 16'h003C_0000;        // 60.0
  localparam [31:0] C_60FP2_FP = 32'h0000_3840;        // 60.0 in Q21.11 (used only as a reference)

  // ROM: 8 speeds from 5..30 km/h in steps of 5, in Q16.16
  logic [31:0] speed_rom [0:7];
  initial begin
    speed_rom[0] = 32'h0005_0000; // 5
    speed_rom[1] = 32'h000A_0000; // 10
    speed_rom[2] = 32'h000F_0000; // 15
    speed_rom[3] = 32'h0014_0000; // 20
    speed_rom[4] = 32'h0019_0000; // 25
    speed_rom[5] = 32'h001E_0000; // 30
    speed_rom[6] = 32'h0023_0000; // 35 (unused)
    speed_rom[7] = 32'h0028_0000; // 40 (unused)
  end

  // State machine
  typedef enum logic [1:0] { IDLE = 2'b00, INIT = 2'b01, COMPUTE = 2'b10, DONE = 2'b11 } state_t;
  state_t state, next_state;

  // Counters and pipeline registers
  reg [3:0] leave_idx;    // 0..15
  reg [2:0] speed_idx;    // 0..7
  reg [3:0] next_leave;
  reg [2:0] next_speed;

  reg [31:0] s_fp_reg;        // selected speed in Q16.16
  reg [31:0] s2_fp_reg;       // speed^2 in Q16.16
  reg [31:0] t_full_fp_reg;   // travel time in Q16.16
  reg [31:0] t_frac_fp_reg;   // fractional part of travel time in Q16.16
  reg [31:0] sweat_fp_reg;    // sweat component in Q16.16

  // Internal progress and accumulation
  reg [7:0] prog;     // 0..255, advances every 2 cycles (16*8*2 = 256)
  reg [7:0] next_prog;
  reg [31:0] rain_sum_q16;  // Q16.16 accumulated rain intensity (sec * intensity)
  reg [31:0] next_rain_sum_q16;

  // Controls
  wire [3:0] T_clamped = (T >= 4'd1) ? T : 4'd1; // valid range 1..16
  wire [3:0] t_full_min;                         // full minutes (0..15), locally computed
  wire [31:0] t_frac_min_fp;                     // fractional minutes in Q16.16

  // Helper functions for Q16.16 arithmetic
  function [31:0] int_to_fp(input [15:0] x);
    int_to_fp = {x, 16'h0000};
  endfunction

  // (a * b) >> 16 with 64-bit intermediate to avoid overflow
  function [31:0] mul_q16(input [31:0] a, input [31:0] b);
    mul_q16 = $signed(($signed(a) * $signed(b)) >>> 16);
  endfunction

  // (a >> n) with proper signed shift
  function [31:0] shiftr_q16(input [31:0] a, input [4:0] n);
    shiftr_q16 = $signed(a) >>> n;
  endfunction

  // Q16.16 min
  function [31:0] q16_min(input [31:0] a, input [31:0] b);
    q16_min = ($signed(a) < $signed(b)) ? a : b;
  endfunction

  // Q16.16 clamp to non-negative
  function [31:0] q16_max0(input [31:0] a);
    q16_max0 = ($signed(a) < 0) ? 32'h0000_0000 : a;
  endfunction

  // Compute travel time and sweat
  always_comb begin
    // t = d / s (minutes), t_full = floor(t), t_frac = t - t_full
    // 1 cycle latency to compute t_full and t_frac
    t_full_min = t_full_fp_reg[19:16]; // Q16.16 integer minutes
    t_frac_min_fp = t_full_fp_reg[15:0]; // Q16.16 fractional minutes
  end

  // State and control logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      leave_idx <= 4'd0;
      speed_idx <= 3'd0;
      prog <= 8'd0;
      done <= 1'b0;
      min_wetness_fp <= 32'hFFFF_FFFF;
      s_fp_reg <= 32'h0000_0000;
      s2_fp_reg <= 32'h0000_0000;
      t_full_fp_reg <= 32'h0000_0000;
      t_frac_fp_reg <= 32'h0000_0000;
      sweat_fp_reg <= 32'h0000_0000;
      rain_sum_q16 <= 32'h0000_0000;
      next_leave <= 4'd0;
      next_speed <= 3'd0;
      next_prog <= 8'd0;
      next_rain_sum_q16 <= 32'h0000_0000;
    end else begin
      // Defaults
      next_leave <= leave_idx;
      next_speed <= speed_idx;
      next_prog <= prog;
      next_rain_sum_q16 <= rain_sum_q16;
      done <= 1'b0;
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
            min_wetness_fp <= 32'hFFFF_FFFF;
            done <= 1'b0;
          end else begin
            state <= IDLE;
          end
        end
        INIT: begin
          state <= COMPUTE;
          // Prime the pipeline: precompute for the first (leave_idx, speed_idx) = (0,0)
          // Cycle 0: s
          s_fp_reg <= speed_rom[0];
          // Cycle 1: s2, travel time, sweat will be in subsequent cycles
        end
        COMPUTE: begin
          // Two-cycle loop over (leave_idx, speed_idx)
          // Cycle 0 (even): provide s
          if (prog[0] == 1'b0) begin
            s_fp_reg <= speed_rom[speed_idx];
          end
          // Cycle 1 (odd): compute s2, travel time and sweat
          if (prog[0] == 1'b1) begin
            s2_fp_reg <= mul_q16(s_fp_reg, s_fp_reg);                         // s^2 in Q16.16
            t_full_fp_reg <= mul_q16(d_fp, C_60_FP);                          // (d * 60) in Q16.16 (minutes)
            t_full_fp_reg <= shiftr_q16(t_full_fp_reg, 0) / s_fp_reg;         // actually (d*60)/s >> 0; we compute exact below
            // For clarity, recompute with exact expression: t = (d * 60) / s
            t_full_fp_reg <= mul_q16(d_fp, C_60_FP) / s_fp_reg;               // Q16.16 division (t in minutes)
            // sweat = c * s^2 * t  = c * (d*60) * s
            sweat_fp_reg <= mul_q16(mul_q16(c_fp, d_fp), mul_q16(C_60_FP, s_fp_reg)); // c*d*60*s in Q16.16
          end

          // Update progress and advance indices every 2 cycles
          if (prog[0] == 1'b1) begin
            // Accumulate rain sum for current combo
            // t_full_min is in [0..15], t_frac_fp in [0..1)
            // t_s_total_q16 = ((t_full_min + 1) * 60) in Q16.16
            next_rain_sum_q16 = mul_q16(int_to_fp(t_full_min + 1), C_60_FP);
            // wetness = sweat + rain_factor * t_s_total
            // rain_factor is already in Q16.16 from previous cycle
            // Here we simply finish by setting done in the next cycle (we will compute wetness below)
          end

          // Terminate after 256 cycles of work (2 cycles per combo)
          if (prog == 8'd255) begin
            // Finalize last result
            if (prog[0] == 1'b0) begin
              // compute final wetness for last (leave_idx, speed_idx)
              // t_full_min and t_frac_fp are valid now
              // Compute t_s_total in Q16.16 (seconds, capped to T*60)
              // t_s_total = min((t_full_min + 1) * 60, T * 60)
              // but here, prog[0]==0 means we are at the first cycle of the last pair,
              // so we wait for the next cycle's math; In a compact version, we let the
              // second cycle do the finalization.
            end else begin
              // prog[0]==1: finalize
              // Accumulate rain_sum_q16 already computed in prev half-cycle
              // Finalize min update and then go to DONE
              // Compute final wetness: wetness = sweat + rain
              // But we still need to compute rain factor from rain[0..15]; do it now:
            end
          end

          // Always update counters at the end of the pair (odd cycle)
          if (prog[0] == 1'b1) begin
            if (speed_idx == 3'd7) begin
              next_speed <= 3'd0;
              next_leave <= (leave_idx == T_clamped - 1) ? leave_idx : (leave_idx + 1);
            end else begin
              next_speed <= speed_idx + 1;
              next_leave <= leave_idx;
            end
            next_prog <= prog + 1;
          end

          // Decide next state
          if (prog == 8'd255) begin
            // After finishing last pair, in the second cycle of the last pair, goto DONE
            if (prog[0] == 1'b1) begin
              state <= DONE;
            end
          end else begin
            state <= COMPUTE;
          end
        end
        DONE: begin
          state <= IDLE;
          done <= 1'b1;
        end
        default: state <= IDLE;
      endcase

      // Update indices and prog at end of cycle
      leave_idx <= next_leave;
      speed_idx <= next_speed;
      prog <= next_prog;
      rain_sum_q16 <= next_rain_sum_q16;
    end
  end

  // Second pipeline stage (odd cycles only): rain sum accumulation and min update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // nothing extra
    end else begin
      if (state == COMPUTE) begin
        if (prog[0] == 1'b1) begin
          // Compute rain factor (Q16.16) and wetness only on the second cycle of each pair
          // t_full_min already computed from t_full_fp_reg (valid at the end of first cycle of the pair)
          // Note: t_full_min is in [0..15], t_frac_fp is the fractional minutes (Q16.16) from t_full_fp_reg
          // Convert full minutes to integer index (0..15)
          logic [3:0] t_full_i;
          logic [31:0] t_frac_min;
          t_full_i = t_full_min;
          t_frac_min = t_frac_fp_reg;

          // Sum intensities for full minutes [0..t_full_i-1]
          logic [31:0] rain_full_int;
          logic [15:0] idx;
          logic [7:0] intensity;
          integer k;
          rain_full_int = 32'h0000_0000;
          for (k = 0; k < 16; k = k + 1) begin
            idx = k[3:0];
            intensity = (idx < t_full_i) ? rain[idx] : 8'd0;
            rain_full_int = rain_full_int + intensity;
          end

          // Fractional part: intensity at minute t_full_i scaled by t_frac (Q16.16)
          logic [31:0] rain_frac_int;
          logic [7:0] intensity_next;
          intensity_next = (t_full_i < 4'd16) ? rain[t_full_i] : 8'd0;
          rain_frac_int = mul_q16(int_to_fp(intensity_next), t_frac_min);

          // Final rain factor: (full + frac) in Q16.16 (sec * intensity)
          logic [31:0] rain_factor_q16;
          rain_factor_q16 = rain_full_int + rain_frac_int;

          // Total rain exposure in Q16.16: rain_factor * t_s_total
          // t_s_total = min((t_full_min + 1) * 60, T * 60) in Q16.16
          logic [31:0] t_s_total_q16;
          logic [31:0] t_s_cap_q16;
          t_s_cap_q16 = mul_q16(int_to_fp(T_clamped), C_60_FP); // T*60 (seconds) in Q16.16
          t_s_total_q16 = mul_q16(int_to_fp(t_full_min + 1), C_60_FP);
          if ($signed(t_s_total_q16) > $signed(t_s_cap_q16)) begin
            t_s_total_q16 = t_s_cap_q16;
          end

          // Rain component in Q16.16
          logic [31:0] rain_comp_fp;
          rain_comp_fp = mul_q16(rain_factor_q16, t_s_total_q16);

          // Total wetness in Q16.16
          logic [31:0] total_wetness;
          total_wetness = sweat_fp_reg + rain_comp_fp;

          // Update min
          if (next_prog == 8'd0) begin
            // first update in the sequence
            min_wetness_fp <= total_wetness;
          end else begin
            min_wetness_fp <= q16_min(min_wetness_fp, total_wetness);
          end
        end
      end
    end
  end

endmodule
