module pupil_transport_time(
  input  clk,
  input  rst_n,
  input  start,
  input  [15:0] n,
  input  [15:0] l,
  input  [15:0] v1,
  input  [15:0] v2,
  input  [15:0] k,
  output reg [31:0] time_q16,
  output reg done
);

  // Q16.16 scale factor
  localparam [31:0] ONE_Q16 = 32'h00010000;

  // State machine
  typedef enum logic [1:0] {
    S_IDLE  = 2'b00,
    S_RUN   = 2'b01,
    S_DONE  = 2'b10
  } state_t;

  state_t state, next_state;

  // Registers
  reg [4:0]  iter_cnt;        // up to 16 iterations

  reg [31:0] l_q16;
  reg [31:0] v1_q16;
  reg [31:0] v2_q16;

  reg [31:0] low;
  reg [31:0] high;
  reg [31:0] mid;

  reg [15:0] groups_count;
  reg [15:0] groups_minus1;

  // Fixed denominators
  reg [31:0] sum_v1_v2_q16;   // (v1+v2) in Q16.16
  reg [31:0] diff_v2_v1_q16;  // (v2-v1) in Q16.16

  // combinational signals for iteration
  reg [31:0] mid_next;
  reg [31:0] low_next;
  reg [31:0] high_next;
  reg [4:0]  iter_cnt_next;
  reg        feasible;

  // Internal calculation intermediates (sequentially latched each cycle)
  reg [31:0] gap_q16;
  reg [63:0] num_pikap;
  reg [31:0] pikap_q16;

  reg [63:0] v1_mid_mul;
  reg [31:0] v1_mid_q16;
  reg [31:0] l_minus_v1t_q16;
  reg [63:0] num_y;
  reg [31:0] y_q16;

  reg [47:0] pikap_times_gm1_q16; // Q16.16
  reg [47:0] gc_times_y_q16;      // Q16.16
  reg [47:0] lhs_q16;             // Q16.16

  // Helpers: 16x16 -> 32
  function automatic [31:0] to_q16(input [15:0] x);
    to_q16 = {x,16'b0};
  endfunction

  // Compute groups_count = ceil(n/k), assuming k>0
  function automatic [15:0] ceil_div(input [15:0] a, input [15:0] b);
    reg [16:0] tmp;
    begin
      if (b == 0) begin
        tmp = 17'd0;
      end else begin
        tmp = a + b - 1;
      end
      ceil_div = tmp[16:1] ? tmp[16:1] : (tmp[15:0] + (b - 1)) / b; // safe but will be overridden by next line
    end
  endfunction

  // The above generic function is overly complex; we implement explicitly in always block.

  // Sequential: state and core registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= S_IDLE;
      iter_cnt     <= 5'd0;
      time_q16     <= 32'd0;
      done         <= 1'b0;
      l_q16        <= 32'd0;
      v1_q16       <= 32'd0;
      v2_q16       <= 32'd0;
      low          <= 32'd0;
      high         <= 32'd0;
      mid          <= 32'd0;
      groups_count <= 16'd0;
      groups_minus1<= 16'd0;
      sum_v1_v2_q16<= 32'd0;
      diff_v2_v1_q16<=32'd0;
      gap_q16      <= 32'd0;
      num_pikap    <= 64'd0;
      pikap_q16    <= 32'd0;
      v1_mid_mul   <= 64'd0;
      v1_mid_q16   <= 32'd0;
      l_minus_v1t_q16 <= 32'd0;
      num_y        <= 64'd0;
      y_q16        <= 32'd0;
      pikap_times_gm1_q16 <= 48'd0;
      gc_times_y_q16      <= 48'd0;
      lhs_q16             <= 48'd0;
    end else begin
      state    <= next_state;
      iter_cnt <= iter_cnt_next;

      // Latch bounds and mid
      low  <= low_next;
      high <= high_next;
      mid  <= mid_next;

      // Keep done until next start
      if (state == S_DONE && start)
        done <= 1'b0;
      else if (next_state == S_DONE)
        done <= 1'b1;

      // On start in IDLE: initialize parameters
      if (state == S_IDLE && start) begin
        // Convert to Q16.16
        l_q16  <= {l,16'b0};
        v1_q16 <= {v1,16'b0};
        v2_q16 <= {v2,16'b0};

        // Precompute denominators
        sum_v1_v2_q16   <= { (v1 + v2), 16'b0 };
        diff_v2_v1_q16  <= { (v2 - v1), 16'b0 };

        // groups_count = ceil(n/k)
        if (k == 0) begin
          groups_count <= 16'd0;
        end else begin
          groups_count <= (n + k - 1) / k;
        end
        groups_minus1 <= ((n + k - 1) / k) > 0 ? (((n + k - 1) / k) - 1) : 0;

        // Binary search range: [0, l/v1]
        // high = (l << 16) / v1   (Q16.16)
        if (v1 != 0)
          high <= (({16'd0,l} << 16) / v1);
        else
          high <= 32'hFFFFFFFF; // if v1=0 (degenerate), set large
        low  <= 32'd0;

        iter_cnt <= 5'd0;
        done     <= 1'b0;
      end

      // Per-iteration sequential math (evaluated in S_RUN)
      if (state == S_RUN) begin
        // gap_q16 = l_q16 - v1_q16 * mid (Q16.16)
        v1_mid_mul      <= v1_q16 * mid;                // Q32.32
        v1_mid_q16      <= v1_mid_mul[47:16];           // align back to Q16.16
        gap_q16         <= l_q16 - v1_mid_q16;

        // pikap_q16 = gap / (v1+v2)
        if (sum_v1_v2_q16 != 0)
          num_pikap <= {gap_q16,16'd0};                 // promote for division
        else
          num_pikap <= 64'd0;

        if (sum_v1_v2_q16 != 0)
          pikap_q16 <= num_pikap / sum_v1_v2_q16;       // Q16.16
        else
          pikap_q16 <= 32'd0;

        // y_q16 = (l - v1*mid) / (v2 - v1)
        l_minus_v1t_q16 <= gap_q16;                     // already computed
        if (diff_v2_v1_q16 != 0)
          num_y <= {l_minus_v1t_q16,16'd0};
        else
          num_y <= 64'd0;

        if (diff_v2_v1_q16 != 0)
          y_q16 <= num_y / diff_v2_v1_q16;              // Q16.16
        else
          y_q16 <= 32'd0;

        // pikap*(groups-1)
        pikap_times_gm1_q16 <= pikap_q16 * groups_minus1; // Q16.16 * int -> Q16.16 (lower 32 bits)
        // groups_count * y
        gc_times_y_q16      <= y_q16 * groups_count;      // Q16.16 * int -> Q16.16

        lhs_q16 <= pikap_times_gm1_q16 + gc_times_y_q16;  // Q16.16
      end

      // When leaving S_RUN to S_DONE, latch final result as mid
      if (next_state == S_DONE && state == S_RUN) begin
        time_q16 <= mid_next;
      end
    end
  end

  // Combinational next-state and bounds update, including feasibility decision
  always @* begin
    next_state    = state;
    low_next      = low;
    high_next     = high;
    mid_next      = mid;
    iter_cnt_next = iter_cnt;

    feasible = 1'b0;

    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_RUN;
      end

      S_RUN: begin
        // mid = (low + high) / 2
        mid_next = (low + high) >> 1;

        // Use previous cycle's computed lhs_q16 with current mid to decide feasibility.
        // Compare lhs <= mid
        if (lhs_q16[47:16] <= mid) // align lhs Q16.16 to 32-bit
          feasible = 1'b1;
        else
          feasible = 1'b0;

        if (feasible)
          high_next = mid_next;
        else
          low_next  = mid_next;

        iter_cnt_next = iter_cnt + 1'b1;

        if (iter_cnt == 5'd15) begin
          next_state = S_DONE;
        end
      end

      S_DONE: begin
        if (start)
          next_state = S_RUN; // restart on new start
      end

      default: next_state = S_IDLE;
    endcase
  end

endmodule