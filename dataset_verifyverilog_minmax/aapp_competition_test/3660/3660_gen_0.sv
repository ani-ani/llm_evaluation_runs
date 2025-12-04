module sticker_message_assembler(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // starts computation when high
  input [63:0] message, // 8-character ASCII message (1 char per byte)
  input [2:0] num_stickers, // 0-4 stickers
  input [31:0] sticker_word_0, // 4-character sticker (padded with spaces)
  input [15:0] sticker_price_0,
  input [31:0] sticker_word_1,
  input [15:0] sticker_price_1,
  input [31:0] sticker_word_2,
  input [15:0] sticker_price_2,
  input [31:0] sticker_word_3,
  input [15:0] sticker_price_3,
  output reg done, // high when computation finished
  output reg [15:0] min_cost, // minimal cost (valid only when done=1)
  output reg impossible // high when solution impossible
);

  // Message length and sticker length
  parameter MSG_LEN = 8;
  parameter STK_LEN = 4;
  parameter MAX_STICKERS = 4;
  parameter MAX_LAYERS = 2;

  // Pipeline depth per position: prev placement (1) + current placement (1)
  parameter PL_PER_POS = 2;
  // Keep window of last STK_LEN-1 positions' placements to enforce layer cap
  parameter WINDOW_POS = (STK_LEN - 1); // 3
  // Total placements tracked: current + history
  parameter TOT_PL = PL_PER_POS + WINDOW_POS; // 5

  // DP state dimension sizes
  parameter NUM_POS = MSG_LEN + 1; // 0..8
  parameter NUM_STK = MAX_STICKERS + 1; // 0..4
  parameter NUM_S = 1 << TOT_PL; // 2^5 = 32

  // Storage: 3D cost array [pos][st_used][state_mask]
  reg [15:0] dp_cost [0:NUM_POS-1][0:NUM_STK-1][0:NUM_S-1];
  reg dp_valid [0:NUM_POS-1][0:NUM_STK-1][0:NUM_S-1];
  reg [15:0] next_cost [0:NUM_STK-1][0:NUM_S-1];
  reg next_valid [0:NUM_STK-1][0:NUM_S-1];
  reg [15:0] cur_min;
  reg cur_any_valid;
  integer i, j, k;
  integer pos, st_used, st_new, mask, prev_mask, next_mask;
  integer pop, layers;
  reg [7:0] msg_bytes [0:MSG_LEN-1];
  reg [7:0] sticker_bytes [0:MAX_STICKERS-1][0:STK_LEN-1];
  reg [15:0] sticker_price_reg [0:MAX_STICKERS-1];
  reg [MAX_STICKERS-1:0] valid_place; // 4-bit mask of sticker indices viable at current pos
  reg [15:0] place_cost [0:MAX_STICKERS-1]; // 16-bit cost per sticker at current pos
  reg [MAX_STICKERS-1:0] used_at_prev; // which stickers used in the last (WINDOW_POS..1) steps
  reg [15:0] cost_at_prev; // costs of those stickers for overlap check

  // Decompose 64-bit message and stickers into byte arrays
  always @(*) begin
    msg_bytes[0] = message[7:0];
    msg_bytes[1] = message[15:8];
    msg_bytes[2] = message[23:16];
    msg_bytes[3] = message[31:24];
    msg_bytes[4] = message[39:32];
    msg_bytes[5] = message[47:40];
    msg_bytes[6] = message[55:48];
    msg_bytes[7] = message[63:56];

    sticker_bytes[0][0] = sticker_word_0[7:0];
    sticker_bytes[0][1] = sticker_word_0[15:8];
    sticker_bytes[0][2] = sticker_word_0[23:16];
    sticker_bytes[0][3] = sticker_word_0[31:24];
    sticker_bytes[1][0] = sticker_word_1[7:0];
    sticker_bytes[1][1] = sticker_word_1[15:8];
    sticker_bytes[1][2] = sticker_word_1[23:16];
    sticker_bytes[1][3] = sticker_word_1[31:24];
    sticker_bytes[2][0] = sticker_word_2[7:0];
    sticker_bytes[2][1] = sticker_word_2[15:8];
    sticker_bytes[2][2] = sticker_word_2[23:16];
    sticker_bytes[2][3] = sticker_word_2[31:24];
    sticker_bytes[3][0] = sticker_word_3[7:0];
    sticker_bytes[3][1] = sticker_word_3[15:8];
    sticker_bytes[3][2] = sticker_word_3[23:16];
    sticker_bytes[3][3] = sticker_word_3[31:24];

    sticker_price_reg[0] = sticker_price_0;
    sticker_price_reg[1] = sticker_price_1;
    sticker_price_reg[2] = sticker_price_2;
    sticker_price_reg[3] = sticker_price_3;
  end

  // Determine if sticker s placed at position 'pos' is valid (partial overlaps allowed; spaces are neutral)
  function automatic bit is_sticker_valid(input integer s, input integer pos);
    integer k;
    bit valid;
    valid = 1'b1;
    for (k = 0; k < STK_LEN; k = k + 1) begin
      if ((pos + k) >= MSG_LEN) continue; // out-of-range char is ignored (padding)
      if (sticker_bytes[s][k] !== 8'h20) begin // non-space must match
        if (sticker_bytes[s][k] != msg_bytes[pos + k]) begin
          valid = 1'b0;
        end
      end
    end
    return valid;
  endfunction

  // Main sequential control
  localparam S_IDLE = 2'b00;
  localparam S_RUN  = 2'b01;
  localparam S_DONE = 2'b10;
  reg [1:0] state;
  reg [5:0] cycle; // up to 64 cycles

  // Internal tracking for current/next step
  reg [MAX_STICKERS-1:0] cur_placements; // up to 4 bits (one per sticker) if placed at current pos
  reg [15:0] cur_place_cost;             // cost of those placements (accumulated by bit-parallel add)
  reg [7:0] cur_layer_count;             // number of layers at current position (0..2)
  reg [7:0] overlap_mask;                // which stickers overlap at current position (from prev placement)

  // Parallel bit-parallel addition for up to 4 sticker costs
  function automatic [15:0] sum4(input [15:0] a, input [15:0] b, input [15:0] c, input [15:0] d);
    return (a + b) + (c + d);
  endfunction

  // Apply DP transition for one position using stored prev placement and current candidate
  task apply_transition;
    input integer p_pos;
    input integer p_st_used;
    input integer p_mask;
    input [MAX_STICKERS-1:0] p_prev_place; // which sticker (if any) ended at p_pos-1
    input [15:0] p_prev_place_cost;        // cost of that sticker
    input [MAX_STICKERS-1:0] p_cur_place;  // which sticker (if any) starts at p_pos
    input [15:0] p_cur_place_cost;
    input [7:0] p_layers_at_pos;
    output integer o_mask_next;
    output reg [15:0] o_cost_next;
    output reg o_valid_next;

    integer new_st_used, new_layers, m, bitn, p;
    reg [7:0] hist0, hist1, hist2, hist3, hist4;
    reg [7:0] new_hist0, new_hist1, new_hist2, new_hist3, new_hist4;
    reg [7:0] layers_next;
    reg good;
    begin
      // Extract history bits: earliest -> latest within window
      hist0 = p_mask[0];
      hist1 = p_mask[1];
      hist2 = p_mask[2];
      hist3 = p_mask[3];
      hist4 = p_mask[4];

      // Shift and add current placement bit
      new_hist0 = hist1;
      new_hist1 = hist2;
      new_hist2 = hist3;
      new_hist3 = hist4;
      new_hist4 = (p_cur_place != 0) ? 1'b1 : 1'b0;

      // Count layers on next position (p_pos+1): overlap of current + next if next uses same sticker
      // But simpler: layers_next equals popcount of new_hist4 and any sticker that continues from new_hist4
      // Here we only need to ensure the current position (p_pos) doesn't exceed 2 layers.
      // Already enforced by p_layers_at_pos.
      layers_next = 0;
      // Not needed for next state build; only mask matters here.

      // Update sticker usage count
      new_st_used = p_st_used + ((p_cur_place != 0) ? 1 : 0);

      // Build next mask
      o_mask_next = {new_hist4, new_hist3, new_hist2, new_hist1, new_hist0};

      // Next position must not be over-covered (will be checked on next cycle when new_cur_place is known),
      // so for now we only ensure current layers <= 2 and usage within cap.
      good = (p_layers_at_pos <= MAX_LAYERS) && (new_st_used <= MAX_STICKERS);

      // If valid, compute new cost
      if (good) begin
        o_cost_next = dp_cost[p_pos][p_st_used][p_mask] + p_prev_place_cost + p_cur_place_cost;
        o_valid_next = 1'b1;
      end else begin
        o_cost_next = 16'h0000;
        o_valid_next = 1'b0;
      end
    end
  endtask

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      min_cost <= 16'h0000;
      impossible <= 1'b0;
      state <= S_IDLE;
      cycle <= 6'd0;
      // Clear DP arrays
      for (i = 0; i < NUM_POS; i = i + 1) begin
        for (j = 0; j < NUM_STK; j = j + 1) begin
          for (k = 0; k < NUM_S; k = k + 1) begin
            dp_cost[i][j][k] <= 16'h0000;
            dp_valid[i][j][k] <= 1'b0;
          end
        end
      end
    end else begin
      case (state)
        S_IDLE: begin
          if (start) begin
            // Initialize DP at position 0
            for (j = 0; j < NUM_STK; j = j + 1) begin
              for (k = 0; k < NUM_S; k = k + 1) begin
                dp_cost[0][j][k] <= 16'h0000;
                dp_valid[0][j][k] <= 1'b0;
              end
            end
            dp_cost[0][0][0] <= 16'h0000;
            dp_valid[0][0][0] <= 1'b1;
            state <= S_RUN;
            cycle <= 6'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            min_cost <= 16'h0000;
          end else begin
            done <= 1'b0;
            impossible <= 1'b0;
            min_cost <= 16'h0000;
          end
        end

        S_RUN: begin
          // One position per cycle, up to 8 cycles
          if (cycle < MSG_LEN) begin
            pos = cycle;
            // Determine valid placements at this position
            valid_place = 4'b0000;
            place_cost[0] = 16'h0000;
            place_cost[1] = 16'h0000;
            place_cost[2] = 16'h0000;
            place_cost[3] = 16'h0000;
            for (i = 0; i < MAX_STICKERS; i = i + 1) begin
              if (i < num_stickers) begin
                if (is_sticker_valid(i, pos)) begin
                  valid_place[i] = 1'b1;
                  place_cost[i] = sticker_price_reg[i];
                end
              end
            end

            // Clear next arrays for this position+1
            for (j = 0; j < NUM_STK; j = j + 1) begin
              for (k = 0; k < NUM_S; k = k + 1) begin
                next_cost[j][k] <= 16'hFFFF; // initial high value
                next_valid[j][k] <= 1'b0;
              end
            end

            // Iterate over all prior states at current pos
            for (st_used = 0; st_used < NUM_STK; st_used = st_used + 1) begin
              for (mask = 0; mask < NUM_S; mask = mask + 1) begin
                if (!dp_valid[pos][st_used][mask]) continue;

                // Extract prev placement at pos-1 from mask (bit0)
                prev_mask = mask & 1;
                used_at_prev = {3'b000, prev_mask}; // only bit0 is prev placement; others 0
                cost_at_prev = prev_mask ? dp_cost[pos][st_used][mask] - 0 /* placeholder */ : 16'h0000;
                // The actual cost_at_prev is not the state's cost, but the cost of the sticker used at prev pos.
                // We cannot reconstruct that from dp_cost alone, so we compute it using place_cost[0] based on whether prev_mask is set.
                // We don't know which sticker it was; however, we ensured only one sticker could be placed at a time at a given position,
                // so prev_mask==1 means exactly one sticker was used. To know its cost, we must store it in a side channel.
                // Since we don't have that channel, we approximate by NOT subtracting prev sticker cost in transition.
                // This is okay because per-step we add prev + cur costs; skipping prev cost is offset by adding it at the step it was placed.
                // To fix this, we will instead add costs when we place stickers (not in apply_transition).
                // For now, do not use cost_at_prev here; we will add costs when the sticker is placed.
                cost_at_prev = 16'h0000;

                // Compute layers at this position using history:
                // Count bits among: (a) prev placement (mask[0]), (b) any sticker that continues from the window: mask[4]
                // plus (c) any current choice placed now.
                pop = 0;
                if (mask & 8'b00001) pop = pop + 1; // prev placement at pos-1 overlaps at pos
                if (mask & 8'b10000) pop = pop + 1; // sticker started STK_LEN-1 steps ago overlaps at pos

                // Evaluate options for current position: pick 0 or 1 valid sticker
                cur_placements = 4'b0000;
                cur_place_cost = 16'h0000;
                cur_layer_count = pop; // base layers from history

                // Option 0: no sticker at this pos
                if (cur_layer_count >= 1) begin
                  // A valid state requires at least one layer at this position
                  // If cur_layer_count==0, we cannot skip placing a sticker here.
                  // We allow skip only if pop>=1 (i.e., overlaps already cover this char).
                  next_mask = {mask[3:0], 1'b0};
                  st_new = st_used;
                  // Transition with zero cost addition
                  // Only update if sticker usage unchanged
                  begin
                    integer nm;
                    reg [15:0] cand_cost;
                    reg cand_valid;
                    nm = next_mask;
                    cand_cost = dp_cost[pos][st_used][mask]; // no extra cost
                    cand_valid = 1'b1;
                    if (!next_valid[st_new][nm]) begin
                      next_cost[st_new][nm] <= cand_cost;
                      next_valid[st_new][nm] <= cand_valid;
                    end else begin
                      if (cand_cost < next_cost[st_new][nm]) begin
                        next_cost[st_new][nm] <= cand_cost;
                        next_valid[st_new][nm] <= cand_valid;
                      end
                    end
                  end
                end

                // Option 1: place a valid sticker at this pos (one at a time)
                for (i = 0; i < MAX_STICKERS; i = i + 1) begin
                  if (valid_place[i]) begin
                    // Only one sticker at a time per position
                    cur_placements = (1 << i);
                    cur_place_cost = place_cost[i];
                    cur_layer_count = pop + 1;
                    if (cur_layer_count <= MAX_LAYERS) begin
                      // Shift mask and add this placement
                      next_mask = {mask[3:0], 1'b1};
                      st_new = st_used + 1;
                      if (st_new <= MAX_STICKERS) begin
                        integer nm;
                        reg [15:0] cand_cost;
                        reg cand_valid;
                        nm = next_mask;
                        cand_cost = dp_cost[pos][st_used][mask] + cur_place_cost;
                        cand_valid = 1'b1;
                        if (!next_valid[st_new][nm]) begin
                          next_cost[st_new][nm] <= cand_cost;
                          next_valid[st_new][nm] <= cand_valid;
                        end else begin
                          if (cand_cost < next_cost[st_new][nm]) begin
                            next_cost[st_new][nm] <= cand_cost;
                            next_valid[st_new][nm] <= cand_valid;
                          end
                        end
                      end
                    end
                  end
                end
                // End of per-state processing
              end
            end

            // Commit next arrays into dp for next position
            for (j = 0; j < NUM_STK; j = j + 1) begin
              for (k = 0; k < NUM_S; k = k + 1) begin
                dp_cost[pos+1][j][k] <= next_cost[j][k];
                dp_valid[pos+1][j][k] <= next_valid[j][k];
              end
            end

            cycle <= cycle + 1;
          end else begin
            // After positions, decide minimal cost among all valid final states
            cur_min = 16'hFFFF;
            cur_any_valid = 1'b0;
            pos = MSG_LEN;
            for (j = 0; j < NUM_STK; j = j + 1) begin
              for (k = 0; k < NUM_S; k = k + 1) begin
                if (dp_valid[pos][j][k]) begin
                  cur_any_valid = 1'b1;
                  if (dp_cost[pos][j][k] < cur_min) begin
                    cur_min = dp_cost[pos][j][k];
                  end
                end
              end
            end
            if (cur_any_valid) begin
              done <= 1'b1;
              impossible <= 1'b0;
              min_cost <= cur_min;
            end else begin
              done <= 1'b1;
              impossible <= 1'b1;
              min_cost <= 16'h0000;
            end
            state <= S_DONE;
          end
        end

        S_DONE: begin
          // Wait for start deassert or hold results; stay here until reset or next start
          if (!start) begin
            state <= S_IDLE;
          end
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
