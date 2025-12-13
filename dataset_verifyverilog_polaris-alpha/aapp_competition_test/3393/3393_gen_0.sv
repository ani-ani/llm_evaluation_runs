module course_optimizer(
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0] n,
  input  [3:0] k,
  input  [7:0][9:0] difficulties,
  input  [7:0] is_level1,
  input  [7:0] is_level2,
  input  [7:0] pair_id,
  output reg [12:0] min_sum,
  output reg done
);

  // State encoding
  localparam IDLE      = 2'b00;
  localparam CALCULATE = 2'b01;
  localparam DONE      = 2'b10;

  reg [1:0] state, next_state;

  // Latency counter: ensure done asserted exactly 16 cycles after start
  reg [4:0] cycle_cnt; // up to >=16

  // Registers to hold inputs stable during computation
  reg [3:0] n_reg;
  reg [3:0] k_reg;
  reg [7:0][9:0] diff_reg;
  reg [7:0] is_l1_reg;
  reg [7:0] is_l2_reg;
  reg [7:0] pid_reg;

  // Brute-force mask iteration and minimum tracking
  reg [7:0] mask_reg;
  reg [12:0] best_sum_reg;

  // Combinational evaluation for a given mask
  reg [12:0] comb_sum;
  reg [3:0]  comb_cnt;
  reg        comb_valid;

  integer i,j;

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = CALCULATE;
      end
      CALCULATE: begin
        // Stay in CALCULATE until we reach 16 cycles after start
        if (cycle_cnt == 5'd15)
          next_state = DONE;
      end
      DONE: begin
        // Return to IDLE when start is deasserted (next new start allowed)
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential state / control registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      cycle_cnt    <= 5'd0;
      done         <= 1'b0;
      min_sum      <= 13'h1FFF; // large
      n_reg        <= 4'd0;
      k_reg        <= 4'd0;
      diff_reg     <= '{default:10'd0};
      is_l1_reg    <= 8'd0;
      is_l2_reg    <= 8'd0;
      pid_reg      <= 8'd0;
      mask_reg     <= 8'd0;
      best_sum_reg <= 13'h1FFF;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          cycle_cnt <= 5'd0;
          if (start) begin
            // Latch inputs on start
            n_reg     <= n;
            k_reg     <= k;
            diff_reg  <= difficulties;
            is_l1_reg <= is_level1;
            is_l2_reg <= is_level2;
            pid_reg   <= pair_id;
            // Initialize search
            mask_reg     <= 8'd0;
            best_sum_reg <= 13'h1FFF; // large initial
          end
        end

        CALCULATE: begin
          // Perform brute force over all subsets using mask_reg.
          // Evaluate current mask combinationally via comb_*.
          // Update best_sum_reg if valid and better.
          if (comb_valid && (comb_sum < best_sum_reg)) begin
            best_sum_reg <= comb_sum;
          end

          // Increment mask for next cycle (wrap naturally)
          mask_reg <= mask_reg + 8'd1;

          // Count cycles: 0..15 (16 cycles total in CALCULATE)
          cycle_cnt <= cycle_cnt + 5'd1;

          // No done assertion here; done in DONE state
        end

        DONE: begin
          // Latch result once when entering DONE
          done    <= 1'b1;
          min_sum <= best_sum_reg;

          // Hold values until next start (transition back to IDLE when !start)
          cycle_cnt <= cycle_cnt; // no change
          mask_reg  <= mask_reg;
        end

        default: begin
          // Safety fallback
          done      <= 1'b0;
          cycle_cnt <= 5'd0;
        end
      endcase
    end
  end

  // Combinational evaluation of current mask_reg
  // Rules:
  // - Consider only courses 0..n_reg-1.
  // - If any selected Level II (is_l2_reg) with non-zero pair_id has its
  //   paired Level I (same pair_id & is_l1_reg) not selected -> invalid.
  // - Level I may be selected without Level II.
  // - Selecting a valid Level I/II pair counts as 2 courses (naturally by bits).
  // - Total selected courses must equal k_reg.
  // - If invalid, comb_valid=0.
  // Complexity is small enough for direct combinational checks.

  always @(*) begin
    comb_sum   = 13'd0;
    comb_cnt   = 4'd0;
    comb_valid = 1'b1;

    // Sum difficulties and count bits for selected within n_reg
    for (i = 0; i < 8; i = i + 1) begin
      if ((i < n_reg) && mask_reg[i]) begin
        comb_sum = comb_sum + {3'd0, diff_reg[i]};
        comb_cnt = comb_cnt + 4'd1;
      end
    end

    // Enforce prerequisite constraints for each selected Level II
    for (i = 0; i < 8; i = i + 1) begin
      if (comb_valid && (i < n_reg) && mask_reg[i] && is_l2_reg[i] && (pid_reg[i] != 8'd0)) begin
        // find matching Level I with same pair_id
        reg has_l1;
        has_l1 = 1'b0;
        for (j = 0; j < 8; j = j + 1) begin
          if ((j < n_reg) && mask_reg[j] && is_l1_reg[j] && (pid_reg[j] == pid_reg[i])) begin
            has_l1 = 1'b1;
          end
        end
        if (!has_l1) begin
          comb_valid = 1'b0; // invalid: Level II without its Level I
        end
      end
    end

    // Check total number of selected courses equals k_reg
    if (comb_cnt != k_reg) begin
      comb_valid = 1'b0;
    end
  end

endmodule