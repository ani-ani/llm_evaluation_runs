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

  // Parameters
  localparam MSG_LEN      = 8;
  localparam STK_LEN      = 4;
  localparam MAX_STICKERS = 4;
  localparam INF          = 16'hFFFF; // represent impossible / large cost

  // FSM states
  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_INIT   = 3'd1,
    S_SCAN   = 3'd2,
    S_APPLY  = 3'd3,
    S_NEXT   = 3'd4,
    S_DONE   = 3'd5
  } state_t;

  state_t state, next_state;

  // Latched inputs for processing during run
  reg [63:0] msg_reg;
  reg [2:0]  num_stk_reg;
  reg [31:0] stk_word [0:MAX_STICKERS-1];
  reg [15:0] stk_price[0:MAX_STICKERS-1];

  // Coverage masks per message position; 2 bits per position (max 2 layers)
  reg [1:0] current_cov [0:MSG_LEN-1];
  reg [1:0] best_cov    [0:MSG_LEN-1];

  // Cost trackers
  reg [15:0] current_cost;
  reg [15:0] best_cost;

  // Iteration indices
  reg [2:0] pos_idx;        // 0..7
  reg [1:0] layer_idx;      // 0..1
  reg [1:0] sticker_idx;    // 0..3

  // Control flags
  reg        have_solution;
  reg        match_found;

  // Helper wires
  wire [7:0] msg_char [0:MSG_LEN-1];
  genvar gi;
  generate
    for (gi = 0; gi < MSG_LEN; gi = gi + 1) begin : GEN_MSG_CHARS
      assign msg_char[gi] = msg_reg[63 - (gi*8) -: 8];
    end
  endgenerate

  // Extract sticker chars function
  function automatic [7:0] get_stk_char(
    input [31:0] word,
    input [1:0]  idx
  );
    // idx 0 is the leftmost (MSB) char
    get_stk_char = word[31 - (idx*8) -: 8];
  endfunction

  // Combinational next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end
      S_INIT: begin
        next_state = S_SCAN;
      end
      S_SCAN: begin
        // After scanning all options for this (pos,layer), move to NEXT
        next_state = S_NEXT;
      end
      S_APPLY: begin
        // Not used as distinct multi-cycle state in this implementation
        next_state = S_NEXT;
      end
      S_NEXT: begin
        // Advance indices; when all positions and layers done, go DONE
        if (layer_idx == 2'd1) begin
          if (pos_idx == (MSG_LEN-1)) begin
            next_state = S_DONE;
          end else begin
            next_state = S_SCAN;
          end
        end else begin
          next_state = S_SCAN;
        end
      end
      S_DONE: begin
        if (!start)
          next_state = S_IDLE;
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= S_IDLE;
      done          <= 1'b0;
      min_cost      <= 16'd0;
      impossible    <= 1'b0;
      msg_reg       <= 64'd0;
      num_stk_reg   <= 3'd0;
      for (i = 0; i < MAX_STICKERS; i = i + 1) begin
        stk_word[i]  <= 32'd0;
        stk_price[i] <= 16'd0;
      end
      for (i = 0; i < MSG_LEN; i = i + 1) begin
        current_cov[i] <= 2'd0;
        best_cov[i]    <= 2'd0;
      end
      current_cost  <= 16'd0;
      best_cost     <= INF;
      have_solution <= 1'b0;
      pos_idx       <= 3'd0;
      layer_idx     <= 2'd0;
      sticker_idx   <= 2'd0;
      match_found   <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done       <= 1'b0;
          impossible <= 1'b0;
          if (start) begin
            // Latch inputs
            msg_reg     <= message;
            num_stk_reg <= (num_stickers > MAX_STICKERS[2:0]) ? MAX_STICKERS[2:0] : num_stickers;
            stk_word[0] <= sticker_word_0;
            stk_price[0]<= sticker_price_0;
            stk_word[1] <= sticker_word_1;
            stk_price[1]<= sticker_price_1;
            stk_word[2] <= sticker_word_2;
            stk_price[2]<= sticker_price_2;
            stk_word[3] <= sticker_word_3;
            stk_price[3]<= sticker_price_3;
          end
        end

        S_INIT: begin
          // Reset DP / search state
          for (i = 0; i < MSG_LEN; i = i + 1) begin
            current_cov[i] <= 2'd0;
            best_cov[i]    <= 2'd0;
          end
          current_cost  <= 16'd0;
          best_cost     <= INF;
          have_solution <= 1'b0;
          pos_idx       <= 3'd0;
          layer_idx     <= 2'd0;
          sticker_idx   <= 2'd0;
          match_found   <= 1'b0;
          done          <= 1'b0;
          impossible    <= 1'b0;
        end

        S_SCAN: begin
          // For current (pos_idx, layer_idx), try all stickers and decide
          // Greedy/local DP-like single-step: choose minimal-cost sticker that covers message[pos_idx]
          // while respecting max 2 layers and allowing overlaps.

          reg [15:0] best_local_cost;
          reg [1:0]  best_local_stk;
          reg [1:0]  best_local_start_off;
          reg        found_local;

          best_local_cost      = INF;
          best_local_stk       = 2'd0;
          best_local_start_off = 2'd0;
          found_local          = 1'b0;

          // Search candidate placements
          integer s;
          integer off;
          for (s = 0; s < MAX_STICKERS; s = s + 1) begin
            if (s < num_stk_reg) begin
              for (off = 0; off < STK_LEN; off = off + 1) begin
                integer pos_start;
                integer pos_end;
                integer k;
                reg valid;

                pos_start = pos_idx - off;
                pos_end   = pos_start + STK_LEN - 1;

                if (pos_start < 0 || pos_start >= MSG_LEN)
                  valid = 1'b0;
                else if (pos_end < 0 || pos_end >= MSG_LEN)
                  valid = 1'b0;
                else begin
                  // Ensure sticker_char != ' ' aligns with message char
                  valid = 1'b1;
                  for (k = 0; k < STK_LEN; k = k + 1) begin
                    reg [7:0] sc;
                    integer   p;
                    sc = get_stk_char(stk_word[s], k[1:0]);
                    p  = pos_start + k;
                    if (p >= 0 && p < MSG_LEN) begin
                      if (sc != 8'h20) begin
                        if (sc != msg_char[p]) begin
                          valid = 1'b0;
                        end
                      end
                    end
                  end

                  // Check layering constraints for all non-space positions
                  if (valid) begin
                    for (k = 0; k < STK_LEN; k = k + 1) begin
                      reg [7:0] sc2;
                      integer   p2;
                      sc2 = get_stk_char(stk_word[s], k[1:0]);
                      p2  = pos_start + k;
                      if (p2 >= 0 && p2 < MSG_LEN && sc2 != 8'h20) begin
                        if (current_cov[p2] >= 2) begin
                          valid = 1'b0;
                        end
                      end
                    end
                  end

                  // Ensure it actually covers current position with non-space char
                  if (valid) begin
                    reg [7:0] sc_cur;
                    integer   kcur;
                    kcur   = pos_idx - pos_start;
                    sc_cur = get_stk_char(stk_word[s], kcur[1:0]);
                    if (sc_cur == 8'h20)
                      valid = 1'b0;
                  end
                end

                if (valid) begin
                  if (stk_price[s] < best_local_cost) begin
                    best_local_cost      = stk_price[s];
                    best_local_stk       = s[1:0];
                    best_local_start_off = off[1:0];
                    found_local          = 1'b1;
                  end
                end
              end
            end
          end

          if (found_local) begin
            // Apply chosen sticker placement
            integer kk;
            integer ps;
            ps = pos_idx - best_local_start_off;
            for (kk = 0; kk < STK_LEN; kk = kk + 1) begin
              reg [7:0] sc3;
              integer   p3;
              sc3 = get_stk_char(stk_word[best_local_stk], kk[1:0]);
              p3  = ps + kk;
              if (p3 >= 0 && p3 < MSG_LEN && sc3 != 8'h20) begin
                if (current_cov[p3] < 2)
                  current_cov[p3] <= current_cov[p3] + 1'b1;
              end
            end
            // Update cost with saturation at INF
            if (current_cost + best_local_cost < current_cost)
              current_cost <= INF;
            else if (current_cost + best_local_cost > INF)
              current_cost <= INF;
            else
              current_cost <= current_cost + best_local_cost;

            match_found <= 1'b1;
          end else begin
            match_found <= 1'b0;
          end
        end

        S_NEXT: begin
          // If no match found for this (pos,layer), we simply move on; infeasibility
          // is determined at the end if positions remain uncovered.

          // Advance layer/position counters
          if (layer_idx == 2'd1) begin
            // Finished both layers for this position
            layer_idx <= 2'd0;
            if (pos_idx < (MSG_LEN-1)) begin
              pos_idx <= pos_idx + 1'b1;
            end
          end else begin
            layer_idx <= layer_idx + 1'b1;
          end
        end

        S_DONE: begin
          // Evaluate coverage and determine if solution is valid; update best_cost
          integer j;
          reg all_covered;
          all_covered = 1'b1;
          for (j = 0; j < MSG_LEN; j = j + 1) begin
            if (msg_char[j] != 8'h20) begin
              if (current_cov[j] == 0) begin
                all_covered = 1'b0;
              end
            end
          end

          if (all_covered && current_cost < INF) begin
            have_solution <= 1'b1;
            if (current_cost < best_cost) begin
              best_cost <= current_cost;
              for (j = 0; j < MSG_LEN; j = j + 1) begin
                best_cov[j] <= current_cov[j];
              end
            end
          end

          done <= 1'b1;
          if (have_solution || all_covered) begin
            // If we found a valid covering, output its cost (best among runs)
            if (all_covered && current_cost < best_cost)
              min_cost <= current_cost;
            else
              min_cost <= best_cost;
            impossible <= 1'b0;
          end else begin
            min_cost   <= 16'd0;
            impossible <= 1'b1;
          end
        end

        default: ;
      endcase
    end
  end

endmodule