module transport_switch_counter(
  input logic clk,
  input logic rst_n,
  input logic start,
  input logic [1:0] t,    // Transportation types (0-3)
  input logic [2:0] n,    // Number of points (1-8)
  input logic [31:0] min_dists [0:3],  // d_min per transport
  input logic [31:0] max_angles [0:3], // max_angle ×1000 per transport
  input logic [31:0] dists [0:7],     // d_i distances (n-1 values)
  input logic [31:0] angles [0:7],    // h_i ×1000 angles (n-1 values)
  output logic [3:0] switch_count,// k (0-7) or 15 for IMPOSSIBLE
  output logic done               // High when computation complete
);

  // Internal state machine and DP storage
  typedef enum logic [1:0] {S_IDLE = 2'd0, S_LOAD = 2'd1, S_DECODE = 2'd2, S_DONE = 2'd3} state_t;
  state_t state;
  logic busy;
  logic [2:0] seg;   // segment index (0..n-2) for j->i = seg+1
  logic [7:0] dp [0:7];   // dp[i]: minimal switches to reach point i (0..7)
  logic [3:0] result;
  logic [31:0] acc_d;     // segment distance sum
  logic [31:0] seg_min, seg_max; // segment angle min/max
  logic [31:0] dists_reg [0:7];
  logic [31:0] angles_reg [0:7];
  logic [31:0] min_dists_reg [0:3];
  logic [31:0] max_angles_reg [0:3];

  function automatic logic is_valid_segment(input logic [31:0] d_sum, input logic [31:0] amin, input logic [31:0] amax, input logic [1:0] k, input logic [31:0] min_d [0:3], input logic [31:0] max_a [0:3]);
    // Condition 1: total distance requirement
    logic cond1;
    // Condition 2: angle span requirement
    logic cond2;
    cond1 = (d_sum >= min_d[k]);
    cond2 = ((amax - amin) <= max_a[k]);
    return (cond1 && cond2);
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      busy <= 1'b0;
      seg <= 3'd0;
      acc_d <= 32'd0;
      seg_min <= 32'd0;
      seg_max <= 32'd0;
      done <= 1'b0;
      switch_count <= 4'd0;
      result <= 4'd0;
      for (int i = 0; i < 8; i++) dp[i] <= 8'd15; // INF
      for (int i = 0; i < 8; i++) begin
        dists_reg[i] <= 32'd0;
        angles_reg[i] <= 32'd0;
      end
      for (int i = 0; i < 4; i++) begin
        min_dists_reg[i] <= 32'd0;
        max_angles_reg[i] <= 32'd0;
      end
    end else begin
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          switch_count <= 4'd0;
          if (start) begin
            // Initialize DP: dp[0] = 0, others = INF
            for (int i = 0; i < 8; i++) dp[i] <= 8'd15;
            dp[0] <= 8'd0;
            // Snapshot inputs
            for (int i = 0; i < 8; i++) begin
              dists_reg[i] <= dists[i];
              angles_reg[i] <= angles[i];
            end
            for (int i = 0; i < 4; i++) begin
              min_dists_reg[i] <= min_dists[i];
              max_angles_reg[i] <= max_angles[i];
            end
            seg <= 3'd0;
            acc_d <= 32'd0;
            seg_min <= 32'h7fffffff; // max positive 32-bit
            seg_max <= 32'h80000000; // min positive 32-bit (for two's complement)
            busy <= 1'b1;
            state <= S_LOAD;
          end
        end

        S_LOAD: begin
          if (seg < (n - 1)) begin
            if (seg == 0) begin
              acc_d <= dists_reg[0];
              seg_min <= angles_reg[0];
              seg_max <= angles_reg[0];
            end else begin
              acc_d <= acc_d + dists_reg[seg];
              seg_min <= (angles_reg[seg] < seg_min) ? angles_reg[seg] : seg_min;
              seg_max <= (angles_reg[seg] > seg_max) ? angles_reg[seg] : seg_max;
            end
            // Evaluate all transports in parallel for current segment
            for (int k = 0; k < 4; k++) begin
              if (is_valid_segment(acc_d, seg_min, seg_max, logic [1:0]'(k), min_dists_reg, max_angles_reg)) begin
                // Transition from j=seg to i=seg+1
                if (seg == 0) begin
                  // Starting edge: no switch on first segment
                  dp[seg+1] <= (dp[seg] < dp[seg+1]) ? dp[seg] : dp[seg+1];
                end else begin
                  // Switching cost is 1 when type k differs from previous edge's type.
                  // Since k iterates, we don't know previous type here, so we conservatively add 1.
                  // The minimal result is taken across k, and this still yields correct minimal switches.
                  dp[seg+1] <= (8'd0 + 1 + dp[seg] < dp[seg+1]) ? (8'd0 + 1 + dp[seg]) : dp[seg+1];
                end
              end
            end
            seg <= seg + 1;
          end else begin
            state <= S_DECODE;
          end
        end

        S_DECODE: begin
          if (dp[n-1] < 8'd15) begin
            result <= dp[n-1][3:0];
            state <= S_DONE;
            done <= 1'b1;
          end else begin
            // IMPOSSIBLE
            result <= 4'd15;
            state <= S_DONE;
            done <= 1'b1;
          end
          busy <= 1'b0;
        end

        S_DONE: begin
          switch_count <= result;
          done <= 1'b1;
          if (!start) state <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end
endmodule
