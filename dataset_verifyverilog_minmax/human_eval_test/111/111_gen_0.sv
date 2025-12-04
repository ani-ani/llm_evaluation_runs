module histogram (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input last_char,
  output reg [25:0] max_letters,
  output reg [4:0] max_count,
  output reg done
);

  // State machine
  localparam SM_IDLE  = 2'b00;
  localparam SM_COUNT = 2'b01;
  localparam SM_POST  = 2'b10;

  reg [1:0] state, state_next;
  reg [4:0] counters [0:25]; // 26 counters, each 5-bit (0..31)
  reg [4:0] counters_next [0:25];
  reg [3:0] valid_cnt;       // valid letter counter (limit 16)
  reg [4:0] post_ctr;        // pipeline cycle counter after last_char (0..2)
  reg [4:0] max_count_next;
  reg [25:0] max_letters_next;
  reg is_lowercase;
  reg [4:0] char_idx;
  integer i;

  // Compute derived inputs for the current char_in
  always @(*) begin
    is_lowercase = (char_in >= 8'h61) && (char_in <= 8'h7A);
    char_idx     = char_in[4:0]; // char_in[5] is 1 for 0x60-0x7F, but range is still 0..25
  end

  // Combinational next-state logic
  always @(*) begin
    // Defaults
    state_next       = state;
    valid_cnt        = valid_cnt; // keep
    post_ctr         = post_ctr;  // keep
    max_count_next   = max_count; // keep current value unless we compute in POST
    max_letters_next = max_letters;
    for (i = 0; i < 26; i++) counters_next[i] = counters[i];

    case (state)
      SM_IDLE: begin
        if (start) begin
          // Start counting from this cycle if a valid char
          if (last_char) begin
            // Special case: only one char and it is last
            post_ctr = 1; // first pipeline stage
            state_next = SM_POST;
          end else begin
            state_next = SM_COUNT;
          end
        end
        // No counting in IDLE
      end

      SM_COUNT: begin
        if (last_char) begin
          // We have already incremented counters for this char at this cycle
          post_ctr = 1;
          state_next = SM_POST;
        end
        // Else remain in COUNT
      end

      SM_POST: begin
        // Pipeline: 1->2 cycles, done asserted at cycle 2 (post_ctr==1)
        if (post_ctr == 0) begin
          post_ctr = 1;
        end else if (post_ctr == 1) begin
          // Compute max and mask in cycle 1 of POST
          max_count_next = 5'd0;
          for (i = 0; i < 26; i++) begin
            if (counters[i] > max_count_next) begin
              max_count_next = counters[i];
            end
          end
          max_letters_next = 26'd0;
          for (i = 0; i < 26; i++) begin
            if (counters[i] == max_count_next) begin
              max_letters_next[i] = 1'b1;
            end
          end
          post_ctr = 2;
        end else if (post_ctr == 2) begin
          // Results are valid here; assert done for 1 cycle
          // Hold final state until next start or reset
          state_next = SM_IDLE;
          post_ctr = 0;
        end
      end

      default: begin
        state_next = SM_IDLE;
      end
    endcase
  end

  // Counting logic (only in SM_COUNT or in the same cycle we enter SM_COUNT from SM_IDLE)
  always @(*) begin
    for (i = 0; i < 26; i++) counters_next[i] = counters[i];
    if ((state == SM_COUNT) || (state == SM_IDLE && start)) begin
      if (is_lowercase && valid_cnt < 5'd15) begin
        counters_next[char_idx] = counters[char_idx] + 1;
      end
    end
  end

  // Count valid letters (limit 16)
  always @(*) begin
    valid_cnt = valid_cnt; // hold by default
    if (state == SM_COUNT) begin
      if (is_lowercase && valid_cnt < 5'd15) begin
        valid_cnt = valid_cnt + 1;
      end
    end else if (state == SM_IDLE && start) begin
      // First char processed this cycle in IDLE->COUNT
      if (is_lowercase && valid_cnt < 5'd15) begin
        valid_cnt = valid_cnt + 1;
      end
    end
  end

  // Sequential block
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= SM_IDLE;
      valid_cnt   <= 4'd0;
      post_ctr    <= 5'd0;
      max_count   <= 5'd0;
      max_letters <= 26'd0;
      done        <= 1'b0;
      for (i = 0; i < 26; i++) counters[i] <= 5'd0;
    end else begin
      // Update state and pipeline counters
      state       <= state_next;
      valid_cnt   <= valid_cnt;
      post_ctr    <= post_ctr;
      // Outputs
      max_count   <= max_count_next;
      max_letters <= max_letters_next;
      done        <= (state_next == SM_POST) && (post_ctr == 2);
      // Counters
      for (i = 0; i < 26; i++) counters[i] <= counters_next[i];
    end
  end

endmodule
