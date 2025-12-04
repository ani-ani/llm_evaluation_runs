module minimal_column_deletion (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [23:0] row1,
  input [23:0] row2,
  input [23:0] row3,
  output reg [3:0] result,
  output reg done
);
  // Internal signals and registers
  reg start_d, start_pulse;
  reg [7:0] mask_r;
  reg [2:0] n_r;
  reg [23:0] r1_r, r2_r, r3_r;
  reg [2:0] cols_kept_r, max_kept_r;
  reg [3:0] result_r;

  // FSM states
  typedef enum bit [2:0] { IDLE=3'd0, INIT=3'd1, PROCESS_MASK=3'd2, UPDATE_STATE=3'd3, DONE=3'd4 } fsm_state_t;
  fsm_state_t state, next_state;

  // Extract a 3-bit field from 24-bit row
  function [2:0] get_col (input [23:0] row, input [2:0] idx);
    get_col = row[(idx*3)+:3];
  endfunction

  // Combinational column selector: for each position j, if mask[j]===1 keep row[j], else pad with 4'd9
  always_comb begin
    r1_extracted = 8'(4'd9);
    r2_extracted = 8'(4'd9);
    r3_extracted = 8'(4'd9);
    for (int j = 0; j < 8; j++) begin
      if (mask_r[j]) begin
        r1_extracted[j] = get_col(r1_r, j);
        r2_extracted[j] = get_col(r2_r, j);
        r3_extracted[j] = get_col(r3_r, j);
      end
    end
  end

  // 8-bit 3-bit values each
  logic [2:0] r1_extracted [0:7];
  logic [2:0] r2_extracted [0:7];
  logic [2:0] r3_extracted [0:7];

  // Sorting networks (Bitonic) for 8 elements of 3 bits each (ascending, stable)
  // Stage 0 (pairs 0-1, 2-3, 4-5, 6-7)
  bitonic_stage_3bit #(.WIDTH(3)) s0_01 (.clk(clk), .rst_n(rst_n), .a(r1_extracted[0]), .b(r1_extracted[1]), .small(r1_s1[0]), .big(r1_s1[1]));
  bitonic_stage_3bit #(.WIDTH(3)) s0_23 (.clk(clk), .rst_n(rst_n), .a(r1_extracted[2]), .b(r1_extracted[3]), .small(r1_s1[2]), .big(r1_s1[3]));
  bitonic_stage_3bit #(.WIDTH(3)) s0_45 (.clk(clk), .rst_n(rst_n), .a(r1_extracted[4]), .b(r1_extracted[5]), .small(r1_s1[4]), .big(r1_s1[5]));
  bitonic_stage_3bit #(.WIDTH(3)) s0_67 (.clk(clk), .rst_n(rst_n), .a(r1_extracted[6]), .b(r1_extracted[7]), .small(r1_s1[6]), .big(r1_s1[7]));

  bitonic_stage_3bit #(.WIDTH(3)) s0b_01 (.clk(clk), .rst_n(rst_n), .a(r2_extracted[0]), .b(r2_extracted[1]), .small(r2_s1[0]), .big(r2_s1[1]));
  bitonic_stage_3bit #(.WIDTH(3)) s0b_23 (.clk(clk), .rst_n(rst_n), .a(r2_extracted[2]), .b(r2_extracted[3]), .small(r2_s1[2]), .big(r2_s1[3]));
  bitonic_stage_3bit #(.WIDTH(3)) s0b_45 (.clk(clk), .rst_n(rst_n), .a(r2_extracted[4]), .b(r2_extracted[5]), .small(r2_s1[4]), .big(r2_s1[5]));
  bitonic_stage_3bit #(.WIDTH(3)) s0b_67 (.clk(clk), .rst_n(rst_n), .a(r2_extracted[6]), .b(r2_extracted[7]), .small(r2_s1[6]), .big(r2_s1[7]));

  bitonic_stage_3bit #(.WIDTH(3)) s0c_01 (.clk(clk), .rst_n(rst_n), .a(r3_extracted[0]), .b(r3_extracted[1]), .small(r3_s1[0]), .big(r3_s1[1]));
  bitonic_stage_3bit #(.WIDTH(3)) s0c_23 (.clk(clk), .rst_n(rst_n), .a(r3_extracted[2]), .b(r3_extracted[3]), .small(r3_s1[2]), .big(r3_s1[3]));
  bitonic_stage_3bit #(.WIDTH(3)) s0c_45 (.clk(clk), .rst_n(rst_n), .a(r3_extracted[4]), .b(r3_extracted[5]), .small(r3_s1[4]), .big(r3_s1[5]));
  bitonic_stage_3bit #(.WIDTH(3)) s0c_67 (.clk(clk), .rst_n(rst_n), .a(r3_extracted[6]), .b(r3_extracted[7]), .small(r3_s1[6]), .big(r3_s1[7]));

  // Stage 1 (0-2, 1-3) and (4-6,5-7) with up/down directions
  bitonic_stage_3bit #(.WIDTH(3)) s1_02up (.clk(clk), .rst_n(rst_n), .a(r1_s1[0]), .b(r1_s1[2]), .small(r1_s2[0]), .big(r1_s2[2]));
  bitonic_stage_3bit #(.WIDTH(3)) s1_13up (.clk(clk), .rst_n(rst_n), .a(r1_s1[1]), .b(r1_s1[3]), .small(r1_s2[1]), .big(r1_s2[3]));
  bitonic_stage_3bit #(.WIDTH(3)) s1_46up (.clk(clk), .rst_n(rst_n), .a(r1_s1[4]), .b(r1_s1[6]), .small(r1_s2[4]), .big(r1_s2[6]));
  bitonic_stage_3bit #(.WIDTH(3)) s1_57dn (.clk(clk), .rst_n(rst_n), .a(r1_s1[5]), .b(r1_s1[7]), .small(r1_s2[5]), .big(r1_s2[7]));

  bitonic_stage_3bit #(.WIDTH(3)) s1b_02up (.clk(clk), .rst_n(rst_n), .a(r2_s1[0]), .b(r2_s1[2]), .small(r2_s2[0]), .big(r2_s2[2]));
  bitonic_stage_3bit #(.WIDTH(3)) s1b_13up (.clk(clk), .rst_n(rst_n), .a(r2_s1[1]), .b(r2_s1[3]), .small(r2_s2[1]), .big(r2_s2[3]));
  bitonic_stage_3bit #(.WIDTH(3)) s1b_46up (.clk(clk), .rst_n(rst_n), .a(r2_s1[4]), .b(r2_s1[6]), .small(r2_s2[4]), .big(r2_s2[6]));
  bitonic_stage_3bit #(.WIDTH(3)) s1b_57dn (.clk(clk), .rst_n(rst_n), .a(r2_s1[5]), .b(r2_s1[7]), .small(r2_s2[5]), .big(r2_s2[7]));

  bitonic_stage_3bit #(.WIDTH(3)) s1c_02up (.clk(clk), .rst_n(rst_n), .a(r3_s1[0]), .b(r3_s1[2]), .small(r3_s2[0]), .big(r3_s2[2]));
  bitonic_stage_3bit #(.WIDTH(3)) s1c_13up (.clk(clk), .rst_n(rst_n), .a(r3_s1[1]), .b(r3_s1[3]), .small(r3_s2[1]), .big(r3_s2[3]));
  bitonic_stage_3bit #(.WIDTH(3)) s1c_46up (.clk(clk), .rst_n(rst_n), .a(r3_s1[4]), .b(r3_s1[6]), .small(r3_s2[4]), .big(r3_s2[6]));
  bitonic_stage_3bit #(.WIDTH(3)) s1c_57dn (.clk(clk), .rst_n(rst_n), .a(r3_s1[5]), .b(r3_s1[7]), .small(r3_s2[5]), .big(r3_s2[7]));

  // Stage 2 (0-4,1-5,2-6,3-7) all up
  bitonic_stage_3bit #(.WIDTH(3)) s2_04up (.clk(clk), .rst_n(rst_n), .a(r1_s2[0]), .b(r1_s2[4]), .small(r1_s3[0]), .big(r1_s3[4]));
  bitonic_stage_3bit #(.WIDTH(3)) s2_15up (.clk(clk), .rst_n(rst_n), .a(r1_s2[1]), .b(r1_s2[5]), .small(r1_s3[1]), .big(r1_s3[5]));
  bitonic_stage_3bit #(.WIDTH(3)) s2_26up (.clk(clk), .rst_n(rst_n), .a(r1_s2[2]), .b(r1_s2[6]), .small(r1_s3[2]), .big(r1_s3[6]));
  bitonic_stage_3bit #(.WIDTH(3)) s2_37up (.clk(clk), .rst_n(rst_n), .a(r1_s2[3]), .b(r1_s2[7]), .small(r1_s3[3]), .big(r1_s3[7]));

  bitonic_stage_3bit #(.WIDTH(3)) s2b_04up (.clk(clk), .rst_n(rst_n), .a(r2_s2[0]), .b(r2_s2[4]), .small(r2_s3[0]), .big(r2_s3[4]));
  bitonic_stage_3bit #(.WIDTH(3)) s2b_15up (.clk(clk), .rst_n(rst_n), .a(r2_s2[1]), .b(r2_s2[5]), .small(r2_s3[1]), .big(r2_s3[5]));
  bitonic_stage_3bit #(.WIDTH(3)) s2b_26up (.clk(clk), .rst_n(rst_n), .a(r2_s2[2]), .b(r2_s2[6]), .small(r2_s3[2]), .big(r2_s3[6]));
  bitonic_stage_3bit #(.WIDTH(3)) s2b_37up (.clk(clk), .rst_n(rst_n), .a(r2_s2[3]), .b(r2_s2[7]), .small(r2_s3[3]), .big(r2_s3[7]));

  bitonic_stage_3bit #(.WIDTH(3)) s2c_04up (.clk(clk), .rst_n(rst_n), .a(r3_s2[0]), .b(r3_s2[4]), .small(r3_s3[0]), .big(r3_s3[4]));
  bitonic_stage_3bit #(.WIDTH(3)) s2c_15up (.clk(clk), .rst_n(rst_n), .a(r3_s2[1]), .b(r3_s2[5]), .small(r3_s3[1]), .big(r3_s3[5]));
  bitonic_stage_3bit #(.WIDTH(3)) s2c_26up (.clk(clk), .rst_n(rst_n), .a(r3_s2[2]), .b(r3_s2[6]), .small(r3_s3[2]), .big(r3_s3[6]));
  bitonic_stage_3bit #(.WIDTH(3)) s2c_37up (.clk(clk), .rst_n(rst_n), .a(r3_s2[3]), .b(r3_s2[7]), .small(r3_s3[3]), .big(r3_s3[7]));

  // Stage 3 (1-2, 5-6) up
  bitonic_stage_3bit #(.WIDTH(3)) s3_12up (.clk(clk), .rst_n(rst_n), .a(r1_s3[1]), .b(r1_s3[2]), .small(r1_s4[1]), .big(r1_s4[2]));
  bitonic_stage_3bit #(.WIDTH(3)) s3_56up (.clk(clk), .rst_n(rst_n), .a(r1_s3[5]), .b(r1_s3[6]), .small(r1_s4[5]), .big(r1_s4[6]));
  bitonic_stage_3bit #(.WIDTH(3)) s3b_12up (.clk(clk), .rst_n(rst_n), .a(r2_s3[1]), .b(r2_s3[2]), .small(r2_s4[1]), .big(r2_s4[2]));
  bitonic_stage_3bit #(.WIDTH(3)) s3b_56up (.clk(clk), .rst_n(rst_n), .a(r2_s3[5]), .b(r2_s3[6]), .small(r2_s4[5]), .big(r2_s4[6]));
  bitonic_stage_3bit #(.WIDTH(3)) s3c_12up (.clk(clk), .rst_n(rst_n), .a(r3_s3[1]), .b(r3_s3[2]), .small(r3_s4[1]), .big(r3_s4[2]));
  bitonic_stage_3bit #(.WIDTH(3)) s3c_56up (.clk(clk), .rst_n(rst_n), .a(r3_s3[5]), .b(r3_s3[6]), .small(r3_s4[5]), .big(r3_s4[6]));

  // Pass-throughs for other indices (kept stable)
  assign r1_s4[0] = r1_s3[0];
  assign r1_s4[3] = r1_s3[3];
  assign r1_s4[4] = r1_s3[4];
  assign r1_s4[7] = r1_s3[7];

  assign r2_s4[0] = r2_s3[0];
  assign r2_s4[3] = r2_s3[3];
  assign r2_s4[4] = r2_s3[4];
  assign r2_s4[7] = r2_s3[7];

  assign r3_s4[0] = r3_s3[0];
  assign r3_s4[3] = r3_s3[3];
  assign r3_s4[4] = r3_s3[4];
  assign r3_s4[7] = r3_s3[7];

  // Stage 4 (0-2, 1-3) up, (4-5, 6-7) up
  bitonic_stage_3bit #(.WIDTH(3)) s4_02up (.clk(clk), .rst_n(rst_n), .a(r1_s4[0]), .b(r1_s4[2]), .small(r1_s5[0]), .big(r1_s5[2]));
  bitonic_stage_3bit #(.WIDTH(3)) s4_13up (.clk(clk), .rst_n(rst_n), .a(r1_s4[1]), .b(r1_s4[3]), .small(r1_s5[1]), .big(r1_s5[3]));
  bitonic_stage_3bit #(.WIDTH(3)) s4_45up (.clk(clk), .rst_n(rst_n), .a(r1_s4[4]), .b(r1_s4[5]), .small(r1_s5[4]), .big(r1_s5[5]));
  bitonic_stage_3bit #(.WIDTH(3)) s4_67up (.clk(clk), .rst_n(rst_n), .a(r1_s4[6]), .b(r1_s4[7]), .small(r1_s5[6]), .big(r1_s5[7]));

  bitonic_stage_3bit #(.WIDTH(3)) s4b_02up (.clk(clk), .rst_n(rst_n), .a(r2_s4[0]), .b(r2_s4[2]), .small(r2_s5[0]), .big(r2_s5[2]));
  bitonic_stage_3bit #(.WIDTH(3)) s4b_13up (.clk(clk), .rst_n(rst_n), .a(r2_s4[1]), .b(r2_s4[3]), .small(r2_s5[1]), .big(r2_s5[3]));
  bitonic_stage_3bit #(.WIDTH(3)) s4b_45up (.clk(clk), .rst_n(rst_n), .a(r2_s4[4]), .b(r2_s4[5]), .small(r2_s5[4]), .big(r2_s5[5]));
  bitonic_stage_3bit #(.WIDTH(3)) s4b_67up (.clk(clk), .rst_n(rst_n), .a(r2_s4[6]), .b(r2_s4[7]), .small(r2_s5[6]), .big(r2_s5[7]));

  bitonic_stage_3bit #(.WIDTH(3)) s4c_02up (.clk(clk), .rst_n(rst_n), .a(r3_s4[0]), .b(r3_s4[2]), .small(r3_s5[0]), .big(r3_s5[2]));
  bitonic_stage_3bit #(.WIDTH(3)) s4c_13up (.clk(clk), .rst_n(rst_n), .a(r3_s4[1]), .b(r3_s4[3]), .small(r3_s5[1]), .big(r3_s5[3]));
  bitonic_stage_3bit #(.WIDTH(3)) s4c_45up (.clk(clk), .rst_n(rst_n), .a(r3_s4[4]), .b(r3_s4[5]), .small(r3_s5[4]), .big(r3_s5[5]));
  bitonic_stage_3bit #(.WIDTH(3)) s4c_67up (.clk(clk), .rst_n(rst_n), .a(r3_s4[6]), .b(r3_s4[7]), .small(r3_s5[6]), .big(r3_s5[7]));

  // Final sorted outputs
  assign r1_sorted = r1_s5;
  assign r2_sorted = r2_s5;
  assign r3_sorted = r3_s5;

  // Comparator across three rows for first k elements
  logic is_match;
  always_comb begin
    case (cols_kept_r)
      3'd0: is_match = 1'b1; // empty subset always matches
      3'd1: is_match = (r1_sorted[0] == r2_sorted[0]) && (r2_sorted[0] == r3_sorted[0]);
      3'd2: is_match = (r1_sorted[0] == r2_sorted[0]) && (r2_sorted[0] == r3_sorted[0]) &&
                       (r1_sorted[1] == r2_sorted[1]) && (r2_sorted[1] == r3_sorted[1]);
      3'd3: is_match = (r1_sorted[0] == r2_sorted[0]) && (r2_sorted[0] == r3_sorted[0]) &&
                       (r1_sorted[1] == r2_sorted[1]) && (r2_sorted[1] == r3_sorted[1]) &&
                       (r1_sorted[2] == r2_sorted[2]) && (r2_sorted[2] == r3_sorted[2]);
      3'd4: is_match = (r1_sorted[0] == r2_sorted[0]) && (r2_sorted[0] == r3_sorted[0]) &&
                       (r1_sorted[1] == r2_sorted[1]) && (r2_sorted[1] == r3_sorted[1]) &&
                       (r1_sorted[2] == r2_sorted[2]) && (r2_sorted[2] == r3_sorted[2]) &&
                       (r1_sorted[3] == r2_sorted[3]) && (r2_sorted[3] == r3_sorted[3]);
      3'd5: is_match = (r1_sorted[0] == r2_sorted[0]) && (r2_sorted[0] == r3_sorted[0]) &&
                       (r1_sorted[1] == r2_sorted[1]) && (r2_sorted[1] == r3_sorted[1]) &&
                       (r1_sorted[2] == r2_sorted[2]) && (r2_sorted[2] == r3_sorted[2]) &&
                       (r1_sorted[3] == r2_sorted[3]) && (r2_sorted[3] == r3_sorted[3]) &&
                       (r1_sorted[4] == r2_sorted[4]) && (r2_sorted[4] == r3_sorted[4]);
      3'd6: is_match = (r1_sorted[0] == r2_sorted[0]) && (r2_sorted[0] == r3_sorted[0]) &&
                       (r1_sorted[1] == r2_sorted[1]) && (r2_sorted[1] == r3_sorted[1]) &&
                       (r1_sorted[2] == r2_sorted[2]) && (r2_sorted[2] == r3_sorted[2]) &&
                       (r1_sorted[3] == r2_sorted[3]) && (r2_sorted[3] == r3_sorted[3]) &&
                       (r1_sorted[4] == r2_sorted[4]) && (r2_sorted[4] == r3_sorted[4]) &&
                       (r1_sorted[5] == r2_sorted[5]) && (r2_sorted[5] == r3_sorted[5]);
      3'd7: is_match = (r1_sorted[0] == r2_sorted[0]) && (r2_sorted[0] == r3_sorted[0]) &&
                       (r1_sorted[1] == r2_sorted[1]) && (r2_sorted[1] == r3_sorted[1]) &&
                       (r1_sorted[2] == r2_sorted[2]) && (r2_sorted[2] == r3_sorted[2]) &&
                       (r1_sorted[3] == r2_sorted[3]) && (r2_sorted[3] == r3_sorted[3]) &&
                       (r1_sorted[4] == r2_sorted[4]) && (r2_sorted[4] == r3_sorted[4]) &&
                       (r1_sorted[5] == r2_sorted[5]) && (r2_sorted[5] == r3_sorted[5]) &&
                       (r1_sorted[6] == r2_sorted[6]) && (r2_sorted[6] == r3_sorted[6]);
      default: is_match = 1'b0; // should not happen (n <= 8)
    endcase
  end

  // Count bits in mask (combinational)
  logic [3:0] popcnt_comb;
  always_comb begin
    popcnt_comb = 4'(mask_r[0]) + 4'(mask_r[1]) + 4'(mask_r[2]) + 4'(mask_r[3]) +
                  4'(mask_r[4]) + 4'(mask_r[5]) + 4'(mask_r[6]) + 4'(mask_r[7]);
  end

  // State register and done, result
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 4'd0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      result <= result_r;
      done <= (next_state == DONE);
    end
  end

  // start pulse detection
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d <= 1'b0;
    end else begin
      start_d <= start;
    end
  end
  assign start_pulse = start && !start_d;

  // Capture inputs when INIT
  always_ff @(posedge clk) begin
    if (state == INIT) begin
      mask_r <= 8'd0;
      n_r <= n;
      r1_r <= row1;
      r2_r <= row2;
      r3_r <= row3;
      max_kept_r <= 3'd0;
    end else if (state == PROCESS_MASK) begin
      mask_r <= mask_r + 1; // iterate masks
    end
  end

  // Update max_kept and compute result in UPDATE_STATE
  always_ff @(posedge clk) begin
    if (state == UPDATE_STATE) begin
      cols_kept_r <= popcnt_comb;
      if (is_match && (popcnt_comb > max_kept_r)) begin
        max_kept_r <= popcnt_comb;
      end
      // result is finalized only when leaving UPDATE_STATE after last mask
      result_r <= (n_r - ((is_match && (popcnt_comb > max_kept_r)) ? popcnt_comb : max_kept_r));
    end
  end

  // FSM next-state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE:   if (start_pulse) next_state = INIT;
      INIT:   next_state = PROCESS_MASK;
      PROCESS_MASK: begin
        // After increment in PROCESS_MASK, check if done (mask exceeded (1<<n)-1)
        if (mask_r == (8'(1) << n_r) - 1) next_state = UPDATE_STATE;
        else next_state = PROCESS_MASK;
      end
      UPDATE_STATE: next_state = DONE;
      DONE: if (start_pulse) next_state = INIT; else next_state = DONE;
      default: next_state = IDLE;
    endcase
  end

  // Inter-stage wires (sorted network stages)
  logic [2:0] r1_s1 [0:7], r1_s2 [0:7], r1_s3 [0:7];
  logic [2:0] r2_s1 [0:7], r2_s2 [0:7], r2_s3 [0:7];
  logic [2:0] r3_s1 [0:7], r3_s2 [0:7], r3_s3 [0:7];
  logic [2:0] r1_s4 [0:7], r1_s5 [0:7];
  logic [2:0] r2_s4 [0:7], r2_s5 [0:7];
  logic [2:0] r3_s4 [0:7], r3_s5 [0:7];
  logic [2:0] r1_sorted [0:7];
  logic [2:0] r2_sorted [0:7];
  logic [2:0] r3_sorted [0:7];
endmodule

// Stable comparator stage for 3-bit values (WIDTH param unused but kept generic)
module bitonic_stage_3bit #(
  parameter WIDTH = 3
) (
  input clk,
  input rst_n,
  input [WIDTH-1:0] a,
  input [WIDTH-1:0] b,
  output reg [WIDTH-1:0] small,
  output reg [WIDTH-1:0] big
);
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      small <= '0;
      big   <= '0;
    end else begin
      if (a <= b) begin
        small <= a;
        big   <= b;
      end else begin
        small <= b;
        big   <= a;
      end
    end
  end
endmodule