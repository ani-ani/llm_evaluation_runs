module ice_cream_optimizer(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [1:0] k,
  input [8:0] a,
  input [8:0] b,
  input [8:0] t [0:3],
  input [8:0] u [0:3][0:3],
  output reg [31:0] max_ratio,
  output reg done
);

  // State encoding
  localparam IDLE        = 3'd0;
  localparam INIT_V      = 3'd1;
  localparam LOOP_S      = 3'd2;
  localparam INNER_SETUP = 3'd3;
  localparam INNER_LOOP  = 3'd4;
  localparam NEXT_S      = 3'd5;
  localparam FINISH      = 3'd6;

  reg [2:0] state, next_state;

  // Latched inputs
  reg [3:0] n_r;
  reg [1:0] k_r;
  reg [8:0] a_r, b_r;
  reg [8:0] t_r [0:3];
  reg [8:0] u_r [0:3][0:3];

  // DP arrays
  // max_tastiness[s]: signed 14-bit (index 1..16). Index 0 unused.
  reg signed [13:0] max_tastiness [0:16];
  reg signed [13:0] v [0:3];            // best tastiness ending with flavor j

  // Loop indices and temporaries
  reg [4:0] s;        // 1..16
  reg [1:0] j;        // 0..3 flavors
  reg [1:0] p;        // 0..3 previous flavors

  reg [1:0] best_prev_j;                 // best flavor index for current j
  reg signed [13:0] best_prev_val;       // best v[p] + u[p][j]

  // Intermediate arithmetic for each s
  reg signed [17:0] denom;               // a*s + b (fits in < 2^18)
  reg signed [13:0] mt_s;                // max_tastiness[s]
  reg [31:0] ratio_q16_16;
  reg [31:0] best_ratio;

  // Division support
  reg        div_start;
  reg        div_busy;
  reg [31:0] div_numer;
  reg [17:0] div_denom;
  reg [31:0] div_quot;
  reg [31:0] div_remainder;

  // Sequential divider (unsigned, restoring, up to 32 cycles)
  // Assumes div_denom > 0.
  localparam DIV_IDLE = 1'b0;
  localparam DIV_RUN  = 1'b1;
  reg div_state;
  reg [5:0] div_cnt;        // up to 32
  reg [63:0] div_work;      // {remainder, partial quotient}
  reg [17:0] div_denom_r;

  // Start signal edge detection
  reg start_d;
  wire start_pulse = start & ~start_d;

  integer idx_i, idx_j;

  // Edge detection and state registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d <= 1'b0;
      state   <= IDLE;
    end else begin
      start_d <= start;
      state   <= next_state;
    end
  end

  // Division logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      div_state     <= DIV_IDLE;
      div_busy      <= 1'b0;
      div_cnt       <= 6'd0;
      div_work      <= 64'd0;
      div_denom_r   <= 18'd0;
      div_quot      <= 32'd0;
      div_remainder <= 32'd0;
    end else begin
      case (div_state)
        DIV_IDLE: begin
          if (div_start) begin
            div_busy    <= 1'b1;
            div_cnt     <= 6'd32;
            div_denom_r <= div_denom;
            // Initialize work: remainder=0, quotient=numerator
            div_work    <= {32'd0, div_numer};
            div_state   <= DIV_RUN;
          end else begin
            div_busy <= 1'b0;
          end
        end
        DIV_RUN: begin
          if (div_cnt != 0) begin
            // Shift left remainder:quotient
            div_work <= {div_work[62:0], 1'b0};
            // Try subtract denom from remainder
            if (div_work[63:46] >= div_denom_r) begin
              div_work[63:46] <= div_work[63:46] - div_denom_r;
              div_work[0]     <= 1'b1; // set LSB of quotient
            end
            div_cnt <= div_cnt - 6'd1;
          end else begin
            // Done
            div_busy      <= 1'b0;
            div_state     <= DIV_IDLE;
            div_quot      <= div_work[31:0];
            div_remainder <= div_work[63:32];
          end
        end
      endcase
    end
  end

  // Main FSM: datapath/control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done       <= 1'b0;
      max_ratio  <= 32'd0;
      best_ratio <= 32'd0;
      s          <= 5'd0;
      j          <= 2'd0;
      p          <= 2'd0;
      best_prev_j   <= 2'd0;
      best_prev_val <= 14'sd0;
      denom      <= 18'sd0;
      mt_s       <= 14'sd0;
      ratio_q16_16 <= 32'd0;
      div_start  <= 1'b0;
      // clear arrays
      for (idx_i = 0; idx_i <= 16; idx_i = idx_i + 1) begin
        max_tastiness[idx_i] <= 14'sd0;
      end
      for (idx_i = 0; idx_i < 4; idx_i = idx_i + 1) begin
        v[idx_i] <= 14'sd0;
        t_r[idx_i] <= 9'sd0;
      end
      for (idx_i = 0; idx_i < 4; idx_i = idx_i + 1) begin
        for (idx_j = 0; idx_j < 4; idx_j = idx_j + 1) begin
          u_r[idx_i][idx_j] <= 9'sd0;
        end
      end
      n_r <= 4'd0;
      k_r <= 2'd0;
      a_r <= 9'd0;
      b_r <= 9'd0;
    end else begin
      div_start <= 1'b0; // default
      done      <= 1'b0; // default

      case (state)
        IDLE: begin
          if (start_pulse) begin
            // Latch inputs
            n_r <= (n == 4'd0) ? 4'd1 : n; // safeguard
            k_r <= (k == 2'd0) ? 2'd1 : k; // safeguard
            a_r <= a;
            b_r <= b;
            for (idx_i = 0; idx_i < 4; idx_i = idx_i + 1) begin
              t_r[idx_i] <= t[idx_i];
            end
            for (idx_i = 0; idx_i < 4; idx_i = idx_i + 1) begin
              for (idx_j = 0; idx_j < 4; idx_j = idx_j + 1) begin
                u_r[idx_i][idx_j] <= u[idx_i][idx_j];
              end
            end
            // Initialize best ratio
            best_ratio <= 32'd0;
          end
        end

        INIT_V: begin
          // Initialize v[j] = t[j] if j < k_r else very negative
          for (idx_i = 0; idx_i < 4; idx_i = idx_i + 1) begin
            if (idx_i < k_r)
              v[idx_i] <= {{5{t_r[idx_i][8]}}, t_r[idx_i]}; // sign-extend 9->14
            else
              v[idx_i] <= -14'sd8192; // large negative sentinel
          end
          // s = 1, compute max_tastiness[1]
          s <= 5'd1;
          // move to LOOP_S next via next_state
        end

        LOOP_S: begin
          // For current s, first determine mt_s = max over v[j]
          mt_s <= v[0];
          if (v[1] > mt_s) mt_s <= v[1];
          if (v[2] > mt_s) mt_s <= v[2];
          if (v[3] > mt_s) mt_s <= v[3];
          max_tastiness[s] <= mt_s;

          // Compute denominator = a_r * s + b_r (always positive)
          denom <= $signed({1'b0,a_r}) * $signed(s[4:0]) + $signed({1'b0,b_r});

          // Trigger division only if mt_s > 0 and denom > 0
          if (mt_s > 14'sd0 && denom > 0) begin
            div_numer <= {mt_s,16'd0};
            div_denom <= denom[17:0];
            div_start <= 1'b1;
          end else begin
            ratio_q16_16 <= 32'd0;
          end
        end

        INNER_SETUP: begin
          // Wait for division (if any) to complete and update best_ratio
          if (!div_busy) begin
            if (mt_s > 14'sd0 && denom > 0) begin
              ratio_q16_16 <= div_quot;
              if (div_quot > best_ratio)
                best_ratio <= div_quot;
            end

            // Prepare for computing v_new for next s if s < n_r
            if (s < n_r) begin
              j <= 2'd0;
              p <= 2'd0;
              best_prev_val <= -14'sd8192;
              best_prev_j   <= 2'd0;
            end
          end
        end

        INNER_LOOP: begin
          // Compute best previous for each j sequentially
          // We iterate p=0..k_r-1 for current j to find max v[p] + u[p][j]
          if (j < k_r) begin
            if (p < k_r) begin
              // candidate = v[p] + u[p][j]
              // sign-extend u_r 9->14
              reg signed [13:0] u_ext;
              reg signed [13:0] cand;
              u_ext = {{5{u_r[p][j][8]}}, u_r[p][j]};
              cand  = v[p] + u_ext;
              if (cand > best_prev_val) begin
                best_prev_val <= cand;
                best_prev_j   <= p;
              end
              p <= p + 2'd1;
            end else begin
              // Done scanning p for this j -> update v[j]
              // Add base tastiness t[j]
              reg signed [13:0] t_ext;
              t_ext = {{5{t_r[j][8]}}, t_r[j]};
              v[j] <= best_prev_val + t_ext;

              // Move to next j
              j <= j + 2'd1;
              p <= 2'd0;
              best_prev_val <= -14'sd8192;
              best_prev_j   <= 2'd0;
            end
          end
        end

        NEXT_S: begin
          // After finishing v updates for all j for this s, move to next s
          if (s < n_r) begin
            s <= s + 5'd1;
          end
        end

        FINISH: begin
          // All s processed, ensure last s's ratio incorporated
          if (!div_busy) begin
            // If last iteration had valid division, ratio_q16_16 already
            // updated in INNER_SETUP; best_ratio already holds maximum.
            max_ratio <= best_ratio;
            done      <= 1'b1;
          end
        end
      endcase
    end
  end

  // Next-state logic (combinational)
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_pulse)
          next_state = INIT_V;
      end

      INIT_V: begin
        next_state = LOOP_S;
      end

      LOOP_S: begin
        // After launching optional division, go to INNER_SETUP
        next_state = INNER_SETUP;
      end

      INNER_SETUP: begin
        if (!div_busy) begin
          if (s < n_r)
            next_state = INNER_LOOP;
          else
            next_state = FINISH;
        end
      end

      INNER_LOOP: begin
        // Completed all j when j >= k_r and p == 0 (after last update)
        if (j >= k_r && p == 2'd0)
          next_state = NEXT_S;
      end

      NEXT_S: begin
        if (s < n_r)
          next_state = LOOP_S;
        else
          next_state = FINISH;
      end

      FINISH: begin
        // Wait here until a new start pulse
        if (start_pulse)
          next_state = INIT_V;
        else
          next_state = FINISH;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule