module longest_twice_subarray(
  input clk,
  input rst_n,
  input start,
  input [3:0] arr [0:7],
  output reg [3:0] max_length,
  output reg done
);

  // Internal state
  typedef enum logic [1:0] {IDLE, RUN, DONE} state_t;
  state_t state, next_state;

  // Input pipeline
  logic [3:0] arr_reg [0:7];
  logic start_d1, start_pulse;

  // Pointers and counters
  logic [3:0] left, right;
  logic [3:0] cur_len, max_len_reg;
  logic [2:0] cycle_cnt; // 0..15

  // Frequency counters (2-bit saturating at 3)
  logic [1:0] freq [0:15]; // each entry is 2-bit; value 0..3 (3 = "3 or more")
  logic [1:0] freq_next [0:15];

  // Expanded frequency flags for condition checking
  logic freq_is_zero [0:15];
  logic freq_is_two [0:15];
  logic all_zero_or_two;
  logic all_zero_or_two_next;

  // Stage the start pulse
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d1 <= 1'b0;
    end else begin
      start_d1 <= start;
    end
  end
  assign start_pulse = start && ~start_d1; // pulse on rising edge of start

  // Frequency compute: saturating increment/decrement
  genvar i;
  generate
    for (i = 0; i < 16; i = i + 1) begin : freq_next_gen
      // Combinatorial: compute next frequencies for this cycle
      // We'll select exactly one element to increment (arr_reg[right]) and
      // potentially one to decrement (arr_reg[left]) when left moves.
      logic is_right;
      logic is_left;
      logic [1:0] dec_next, inc_next, next_val;

      assign is_right = (arr_reg[right] == i);
      assign is_left  = (left != right) && (arr_reg[left] == i);

      // Decrement when left moves (saturate at 0)
      assign dec_next = (|is_left) ? (freq[i] == 0 ? 0 : (freq[i] - 1)) : freq[i];
      // Increment when right is this element (saturate at 3)
      assign inc_next = (|is_right) ? (freq[i] == 3 ? 3 : (freq[i] + 1)) : dec_next;
      assign next_val = inc_next;

      always_comb begin
        freq_next[i] = next_val;
      end
    end
  endgenerate

  // Validity check combinatorially (current values)
  generate
    for (i = 0; i < 16; i = i + 1) begin : flags_gen
      assign freq_is_zero[i] = (freq[i] == 0);
      assign freq_is_two[i]  = (freq[i] == 2);
    end
  endgenerate
  // All non-zero counters must be == 2
  assign all_zero_or_two = & (freq_is_zero | freq_is_two);

  // Same for next-state (used to update max as we slide left)
  generate
    for (i = 0; i < 16; i = i + 1) begin : flags_next_gen
      assign freq_is_zero[i] = (freq_next[i] == 0);
      assign freq_is_two[i]  = (freq_next[i] == 2);
    end
  endgenerate
  assign all_zero_or_two_next = & (freq_is_zero | freq_is_two);

  // State and datapath sequential update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done  <= 1'b0;
      max_length <= 4'd0;
      left  <= 4'd0;
      right <= 4'd0;
      cur_len <= 4'd0;
      max_len_reg <= 4'd0;
      cycle_cnt <= 3'd0;
      for (int j = 0; j < 16; j++) freq[j] <= 2'b0;
      for (int j = 0; j < 8; j++) arr_reg[j] <= 4'd0;
    end else begin
      // Defaults (will be overridden in each state)
      state <= state;
      done  <= 1'b0;
      max_length <= max_length;
      left  <= left;
      right <= right;
      cur_len <= cur_len;
      max_len_reg <= max_len_reg;
      cycle_cnt <= cycle_cnt;
      for (int j = 0; j < 16; j++) freq[j] <= freq[j];
      for (int j = 0; j < 8; j++) arr_reg[j] <= arr_reg[j];

      case (state)
        IDLE: begin
          if (start_pulse) begin
            // Load input array into internal register
            for (int j = 0; j < 8; j++) arr_reg[j] <= arr[j];
            // Initialize pointers, counters
            left  <= 4'd0;
            right <= 4'd0;
            cur_len <= 4'd0;
            max_len_reg <= 4'd0;
            for (int j = 0; j < 16; j++) freq[j] <= 2'b0;
            cycle_cnt <= 3'd0;
            state <= RUN;
            done  <= 1'b0;
          end
        end

        RUN: begin
          // Update frequency counters with next state
          for (int j = 0; j < 16; j++) freq[j] <= freq_next[j];

          // Left may move 0 or 1 step to reduce freq <= 2; compute next pointers/len
          if (left != right) begin
            // If moving left would cause freq[arr[left]] to go from 2 -> 1, window becomes valid
            if (freq[arr_reg[left]] == 2) begin
              // After moving left, check if all non-zero freq are exactly 2
              if (all_zero_or_two_next) begin
                max_len_reg <= (cur_len > 0) ? (cur_len - 1) : 4'd0;
              end
              left  <= left + 1;
              cur_len <= cur_len - 1;
            end else begin
              // Either freq is 0/1 or 3+ (we don't expect 0/1 with left != right)
              left  <= left + 1;
              cur_len <= cur_len - 1;
            end
          end

          // Try to expand with right if not at end and freq[arr[right]] < 2
          if (right < 4'd7 && freq[arr_reg[right]] < 2) begin
            right <= right + 1;
            cur_len <= cur_len + 1;
          end
          // else: right cannot expand this cycle; left movement handled above

          // Cycle counter and done logic (done at 15 cycles after start)
          cycle_cnt <= cycle_cnt + 3'd1;
          if (cycle_cnt == 3'd14) begin
            state <= DONE;
            done  <= 1'b1;
          end
        end

        DONE: begin
          max_length <= max_len_reg;
          state <= IDLE;
          done  <= 1'b1;
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule
