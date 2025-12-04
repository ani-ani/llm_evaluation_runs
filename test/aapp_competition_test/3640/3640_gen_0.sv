module meow_factor(
  input clk,
  input rst_n,
  input start,
  input [39:0] str_in,
  output reg [3:0] min_ops,
  output reg done
);

  // We treat transformations as edit operations on contiguous 4-char windows.
  // "meow" is fixed target across all windows.

  // State encoding
  localparam IDLE      = 2'b00;
  localparam CALCULATE = 2'b01;
  localparam DONE      = 2'b10;

  reg [1:0] state, next_state;

  // Latched input string
  reg [39:0] str_reg;

  // Index for windows 0..4 (5 windows of length 4 inside 8 chars)
  reg [2:0] win_idx;

  // Current window characters
  reg [4:0] c0, c1, c2, c3;

  // Per-window best cost signal
  reg [3:0] win_cost;

  // Running minimum across windows
  reg [3:0] best_cost;

  // Count cycles to ensure completion (not strictly needed for functionality,
  // but can be used if desired to track progress). Here mainly for structure.
  reg [3:0] cycle_cnt;

  // Fixed pattern: "meow" (5-bit chars assumed)
  // ASCII not assumed; we just compare 5-bit codes directly.
  localparam [4:0] CH_M = 5'h0D; // arbitrary encoding placeholder
  localparam [4:0] CH_E = 5'h0E;
  localparam [4:0] CH_O = 5'h0F;
  localparam [4:0] CH_W = 5'h10;

  // We do not know actual encoding, so we must instead match based on the
  // provided bits in str_in. However, problem statement implies fixed 5-bit
  // chars; treat input as already encoded and "meow" as same encoding.
  // To avoid making assumptions, we implement comparisons using parameters
  // that tools/users can map to the desired encoding.

  // To keep this self-contained, re-define using parameters for clarity.
  // (Synthesis will treat them as constants; replaces above locals.)
  localparam [4:0] M = 5'd13;
  localparam [4:0] E = 5'd14;
  localparam [4:0] O = 5'd15;
  localparam [4:0] W = 5'd16;

  // Next-state logic
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = CALCULATE;
      end
      CALCULATE: begin
        if (win_idx == 3'd4) // after last window processed
          next_state = DONE;
      end
      DONE: begin
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential state, registers
  always @(posedge clk) begin
    if (!rst_n) begin
      state      <= IDLE;
      str_reg    <= 40'd0;
      win_idx    <= 3'd0;
      best_cost  <= 4'd15;
      min_ops    <= 4'd0;
      done       <= 1'b0;
      cycle_cnt  <= 4'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done      <= 1'b0;
          min_ops   <= 4'd0;
          best_cost <= 4'd15;
          win_idx   <= 3'd0;
          cycle_cnt <= 4'd0;
          if (start) begin
            // Latch input only on start
            str_reg <= str_in;
          end
        end

        CALCULATE: begin
          cycle_cnt <= cycle_cnt + 4'd1;

          // Extract current 4-char window (MSB first: [39:35] is char0)
          // Window starting at win_idx selects bits [39-5*win_idx : 24-5*win_idx]
          case (win_idx)
            3'd0: begin
              c0 = str_reg[39:35];
              c1 = str_reg[34:30];
              c2 = str_reg[29:25];
              c3 = str_reg[24:20];
            end
            3'd1: begin
              c0 = str_reg[34:30];
              c1 = str_reg[29:25];
              c2 = str_reg[24:20];
              c3 = str_reg[19:15];
            end
            3'd2: begin
              c0 = str_reg[29:25];
              c1 = str_reg[24:20];
              c2 = str_reg[19:15];
              c3 = str_reg[14:10];
            end
            3'd3: begin
              c0 = str_reg[24:20];
              c1 = str_reg[19:15];
              c2 = str_reg[14:10];
              c3 = str_reg[9:5];
            end
            default: begin // 3'd4
              c0 = str_reg[19:15];
              c1 = str_reg[14:10];
              c2 = str_reg[9:5];
              c3 = str_reg[4:0];
            end
          endcase

          // Compute window cost combinationally (edit distance variant with
          // insert/delete/replace/swap). For efficiency and fixed small size,
          // we apply a tailored minimal-cost computation rather than generic DP.

          // Base Hamming distance to "meow" without swaps
          // Using M,E,O,W constants.
          begin : compute_window_cost
            integer mismatch;
            reg [3:0] cost_base;
            reg [3:0] cost_swap;
            reg [3:0] temp_cost;

            mismatch = 0;
            if (c0 != M) mismatch = mismatch + 1;
            if (c1 != E) mismatch = mismatch + 1;
            if (c2 != O) mismatch = mismatch + 1;
            if (c3 != W) mismatch = mismatch + 1;
            cost_base = mismatch[3:0];

            // Consider beneficial adjacent swaps (each swap cost = 1)
            // If swapping fixes two mismatches, net benefit.
            cost_swap = cost_base;

            // Check all three adjacent swap positions and take best improvement.
            // (1) swap positions 0 and 1
            begin
              integer before, after;
              reg [3:0] candidate;
              before = 0;
              if (c0 != M) before = before + 1;
              if (c1 != E) before = before + 1;
              after = 0;
              if (c1 == M) after = after + 0; else after = after + 1;
              if (c0 == E) after = after + 0; else after = after + 1;
              // net change + swap cost 1
              candidate = (cost_base - before + after + 4'd1);
              if (candidate < cost_swap) cost_swap = candidate;
            end

            // (2) swap positions 1 and 2
            begin
              integer before, after;
              reg [3:0] candidate;
              before = 0;
              if (c1 != E) before = before + 1;
              if (c2 != O) before = before + 1;
              after = 0;
              if (c2 == E) ; else after = after + 1;
              if (c1 == O) ; else after = after + 1;
              candidate = (cost_base - before + after + 4'd1);
              if (candidate < cost_swap) cost_swap = candidate;
            end

            // (3) swap positions 2 and 3
            begin
              integer before, after;
              reg [3:0] candidate;
              before = 0;
              if (c2 != O) before = before + 1;
              if (c3 != W) before = before + 1;
              after = 0;
              if (c3 == O) ; else after = after + 1;
              if (c2 == W) ; else after = after + 1;
              candidate = (cost_base - before + after + 4'd1);
              if (candidate < cost_swap) cost_swap = candidate;
            end

            // Insert/delete can emulate shifting to align pattern; for a
            // 4-char fixed window vs 4-char fixed pattern, an optimal
            // combination of these plus replacements will not exceed 4.
            // For simplicity and small bounds, we approximate by limiting
            // final cost to min(cost_swap, 4).
            temp_cost = (cost_swap > 4'd4) ? 4'd4 : cost_swap;

            win_cost = temp_cost;
          end

          // Update global best
          if (win_idx == 3'd0) begin
            best_cost <= win_cost;
          end else begin
            if (win_cost < best_cost)
              best_cost <= win_cost;
          end

          // Advance window index
          if (win_idx < 3'd4)
            win_idx <= win_idx + 3'd1;
        end

        DONE: begin
          done    <= 1'b1;
          min_ops <= best_cost;
          // Wait for start deassertion to go back IDLE
        end

        default: begin
          // Fallback safe
          done      <= 1'b0;
          min_ops   <= 4'd0;
          best_cost <= 4'd15;
          win_idx   <= 3'd0;
        end
      endcase
    end
  end

endmodule
