module arcade_expected_value(
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0] num_rows,
  input  signed [7:0] payouts [0:9],
  input  [19:0] probs [0:9][0:4],
  output reg signed [31:0] expected_value,
  output reg done
);

  // State encoding
  localparam IDLE    = 2'd0;
  localparam INIT    = 2'd1;
  localparam ITERATE = 2'd2;
  localparam DONE    = 2'd3;

  reg [1:0] state, next_state;

  // Internal memories for expected values (Q10.22)
  reg signed [31:0] E_curr [0:9];
  reg signed [31:0] E_next [0:9];

  // Iteration and index tracking
  reg [6:0] iter_cnt;         // up to 100
  reg [3:0] hole_idx;         // 0..9

  // Max delta tracking (Q10.22, but we only care vs 2^-10 threshold)
  reg signed [31:0] max_delta_abs;
  reg signed [31:0] max_delta_abs_next;

  // Control strobes
  reg start_iter;
  reg iter_done;
  reg update_max_delta;
  reg write_E_next;
  reg load_iter_cnt;
  reg inc_iter;
  reg clear_max_delta;
  reg copy_next_to_curr;

  // Direction indices: 0..4 (up, down, left, right, stay) - example
  // Neighbor computation signals
  reg [3:0] row, col;
  reg [3:0] n_row [0:4];
  reg [3:0] n_col [0:4];
  reg [3:0] n_idx [0:4];
  reg       valid_n [0:4];

  // Combinational for row/col from idx
  // max 4 rows, cols up to 3, but only 10 holes assumed as row*cols layout.
  // We assume a 4x3 grid (12) but restrict to 10: indices 0..9 are valid.
  // For invalid mapping, neighbors marked invalid.

  // Probability * E multiplication
  // probs: Q10.10 (unsigned)
  // E: Q10.22 (signed)
  // product: (10+10 frac) + (10+22 frac) = 42 bits; we align back to Q10.22.

  integer i;
  reg signed [31:0] payout_ext;
  reg signed [31:0] sum_neighbors;
  reg [2:0] d;
  reg [63:0] mult_full;
  reg signed [43:0] mult_se;
  reg signed [31:0] contrib;

  // Threshold for convergence: 1/1024 in Q10.22 = 2^(22-10) = 4096
  localparam signed [31:0] THRESH = 32'sd4096;

  // Row/col decode and neighbors (combinational)
  always @* begin
    // default
    for (i = 0; i < 5; i = i + 1) begin
      n_row[i]   = 4'd15;
      n_col[i]   = 4'd15;
      n_idx[i]   = 4'd15;
      valid_n[i] = 1'b0;
    end

    // derive row/col assuming 3 columns layout
    row = hole_idx / 3;
    col = hole_idx % 3;

    // Validate hole_idx within 0..9
    // If outside, mark all neighbors invalid
    if (hole_idx <= 4'd9) begin
      // up (0)
      if (row > 0 && ((hole_idx - 3) <= 4'd9)) begin
        n_row[0]   = row - 1;
        n_col[0]   = col;
        n_idx[0]   = hole_idx - 3;
        valid_n[0] = (n_idx[0] <= 4'd9);
      end
      // down (1)
      if ((row + 1) < num_rows && ((hole_idx + 3) <= 4'd9)) begin
        n_row[1]   = row + 1;
        n_col[1]   = col;
        n_idx[1]   = hole_idx + 3;
        valid_n[1] = (n_idx[1] <= 4'd9);
      end
      // left (2)
      if (col > 0 && ((hole_idx - 1) <= 4'd9)) begin
        n_row[2]   = row;
        n_col[2]   = col - 1;
        n_idx[2]   = hole_idx - 1;
        valid_n[2] = (n_idx[2] <= 4'd9);
      end
      // right (3)
      if (col < 2 && ((hole_idx + 1) <= 4'd9)) begin
        n_row[3]   = row;
        n_col[3]   = col + 1;
        n_idx[3]   = hole_idx + 1;
        valid_n[3] = (n_idx[3] <= 4'd9);
      end
      // stay/self (4)
      n_row[4]   = row;
      n_col[4]   = col;
      n_idx[4]   = hole_idx;
      valid_n[4] = 1'b1;
    end
  end

  // Combinational expected value update for current hole_idx
  always @* begin
    // Extend payout to Q10.22 (payout is signed 8-bit integer -> shift left 22)
    payout_ext = { {24{payouts[hole_idx][7]}}, payouts[hole_idx] } <<< 22;

    sum_neighbors = 32'sd0;

    for (d = 0; d < 5; d = d + 1) begin
      if (valid_n[d]) begin
        // Multiply probs[hole_idx][d] (20-bit unsigned Q10.10)
        // with E_curr[n_idx[d]] (32-bit signed Q10.22)
        mult_full = probs[hole_idx][d] * E_curr[n_idx[d]];
        // Sign-extend to 44 bits (probs is unsigned, but product gets sign from E_curr)
        mult_se = $signed(mult_full[43:0]);
        // We need to align from Q(10+10).(10+22)=Q20.32 back to Q10.22
        // That is, shift right by 10 bits (32-22) with rounding.
        // Rounding: add 2^9 before shifting.
        if (mult_se[9])
          contrib = (mult_se + 44'sd512) >>> 10;
        else
          contrib = mult_se >>> 10;
        sum_neighbors = sum_neighbors + contrib;
      end
    end

    E_next[hole_idx] = payout_ext + sum_neighbors;
  end

  // Max delta update logic
  reg signed [31:0] delta;
  reg signed [31:0] delta_abs;
  always @* begin
    max_delta_abs_next = max_delta_abs;
    if (update_max_delta) begin
      delta = E_next[hole_idx] - E_curr[hole_idx];
      if (delta[31])
        delta_abs = -delta;
      else
        delta_abs = delta;
      if (delta_abs > max_delta_abs_next)
        max_delta_abs_next = delta_abs;
    end
  end

  // State transition
  always @* begin
    next_state       = state;
    start_iter       = 1'b0;
    iter_done        = 1'b0;
    update_max_delta = 1'b0;
    write_E_next     = 1'b0;
    load_iter_cnt    = 1'b0;
    inc_iter         = 1'b0;
    clear_max_delta  = 1'b0;
    copy_next_to_curr= 1'b0;

    case (state)
      IDLE: begin
        if (start) begin
          next_state    = INIT;
        end
      end

      INIT: begin
        // Initialize all E_curr to 0; this happens in sequential block over all holes
        start_iter    = 1'b1;
        load_iter_cnt = 1'b1;
        clear_max_delta = 1'b1;
        next_state    = ITERATE;
      end

      ITERATE: begin
        // For each hole_idx 0..9 compute E_next and track max delta
        write_E_next     = 1'b1;
        update_max_delta = 1'b1;

        // iter_done strobes when last hole processed in this iteration
        if (hole_idx == 4'd9) begin
          iter_done = 1'b1;
        end

        if (iter_done) begin
          // After finishing all holes, copy E_next -> E_curr and check stopping
          copy_next_to_curr = 1'b1;

          if (max_delta_abs_next < THRESH || iter_cnt == 7'd99) begin
            next_state = DONE;
          end else begin
            inc_iter       = 1'b1;
            clear_max_delta= 1'b1;
            // restart hole_idx from 0 in seq logic
          end
        end
      end

      DONE: begin
        // Wait until start deasserted and then go back to IDLE
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= IDLE;
      iter_cnt       <= 7'd0;
      hole_idx       <= 4'd0;
      max_delta_abs  <= 32'sd0;
      expected_value <= 32'sd0;
      done           <= 1'b0;
      for (i = 0; i < 10; i = i + 1) begin
        E_curr[i] <= 32'sd0;
        E_next[i] <= 32'sd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // prepare for init
            for (i = 0; i < 10; i = i + 1) begin
              E_curr[i] <= 32'sd0;
              E_next[i] <= 32'sd0;
            end
            hole_idx      <= 4'd0;
            iter_cnt      <= 7'd0;
            max_delta_abs <= 32'sd0;
          end
        end

        INIT: begin
          // All E_curr already cleared in IDLE on start
          if (start_iter) begin
            hole_idx <= 4'd0;
          end
          if (load_iter_cnt) begin
            iter_cnt <= 7'd0;
          end
          if (clear_max_delta) begin
            max_delta_abs <= 32'sd0;
          end
        end

        ITERATE: begin
          // Write E_next for current hole
          if (write_E_next) begin
            E_next[hole_idx] <= E_next[hole_idx]; // computed combinationally
          end

          // Update max delta
          if (update_max_delta) begin
            max_delta_abs <= max_delta_abs_next;
          end

          // Advance hole index
          if (hole_idx == 4'd9) begin
            hole_idx <= 4'd0;
          end else begin
            hole_idx <= hole_idx + 4'd1;
          end

          // End of iteration handling
          if (iter_done) begin
            if (copy_next_to_curr) begin
              for (i = 0; i < 10; i = i + 1) begin
                E_curr[i] <= E_next[i];
              end
            end
            if (inc_iter) begin
              iter_cnt <= iter_cnt + 7'd1;
            end
            if (clear_max_delta) begin
              max_delta_abs <= 32'sd0;
            end
          end
        end

        DONE: begin
          done           <= 1'b1;
          expected_value <= E_curr[0];
          // Stay until start is low, transition handled in comb logic
        end
      endcase
    end
  end

endmodule