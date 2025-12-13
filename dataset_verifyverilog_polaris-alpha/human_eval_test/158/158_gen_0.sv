module max_unique_chars (
  input  logic                 clk,
  input  logic                 rst_n,
  input  logic                 start,
  input  logic [3:0][63:0]     word_array,
  output logic [63:0]          result,
  output logic                 done
);

  // FSM state encoding
  typedef enum logic [2:0] {
    IDLE,
    COUNT_UNIQUES,
    COMPARE,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal storage for words
  logic [63:0] words   [3:0];
  logic [3:0]  unique_cnt;

  // Best tracking
  logic [1:0]  best_idx;
  logic [3:0]  best_unique_cnt;
  logic [63:0] best_word;

  // Latch inputs and reset best trackers on start
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      words[0]        <= 64'd0;
      words[1]        <= 64'd0;
      words[2]        <= 64'd0;
      words[3]        <= 64'd0;
      unique_cnt      <= 4'd0;
      best_idx        <= 2'd0;
      best_unique_cnt <= 4'd0;
      best_word       <= 64'd0;
      result          <= 64'd0;
      done            <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Latch input words
            words[0]        <= word_array[0];
            words[1]        <= word_array[1];
            words[2]        <= word_array[2];
            words[3]        <= word_array[3];
            // Clear best trackers (will be set in COMPARE)
            best_idx        <= 2'd0;
            best_unique_cnt <= 4'd0;
            best_word       <= 64'd0;
          end
        end

        COUNT_UNIQUES: begin
          // unique_cnt is combinationally determined; nothing sequential here
        end

        COMPARE: begin
          // Determine best word based on unique_cnt and lexicographic order
          logic [1:0]  cand_idx;
          logic [3:0]  cand_uc;
          logic [63:0] cand_word;

          // Initialize candidate to index 0
          cand_idx  = 2'd0;
          cand_uc   = unique_cnt[0];
          cand_word = words[0];

          // Compare with index 1
          if (unique_cnt[1] > cand_uc) begin
            cand_idx  = 2'd1;
            cand_uc   = unique_cnt[1];
            cand_word = words[1];
          end else if (unique_cnt[1] == cand_uc) begin
            if (words[1] < cand_word) begin
              cand_idx  = 2'd1;
              cand_uc   = unique_cnt[1];
              cand_word = words[1];
            end
          end

          // Compare with index 2
          if (unique_cnt[2] > cand_uc) begin
            cand_idx  = 2'd2;
            cand_uc   = unique_cnt[2];
            cand_word = words[2];
          end else if (unique_cnt[2] == cand_uc) begin
            if (words[2] < cand_word) begin
              cand_idx  = 2'd2;
              cand_uc   = unique_cnt[2];
              cand_word = words[2];
            end
          end

          // Compare with index 3
          if (unique_cnt[3] > cand_uc) begin
            cand_idx  = 2'd3;
            cand_uc   = unique_cnt[3];
            cand_word = words[3];
          end else if (unique_cnt[3] == cand_uc) begin
            if (words[3] < cand_word) begin
              cand_idx  = 2'd3;
              cand_uc   = unique_cnt[3];
              cand_word = words[3];
            end
          end

          best_idx        <= cand_idx;
          best_unique_cnt <= cand_uc;
          best_word       <= cand_word;
        end

        DONE: begin
          done   <= 1'b1;
          result <= best_word;
        end

        default: begin
          // Should not occur
        end
      endcase
    end
  end

  // Next-state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = COUNT_UNIQUES;
      end

      COUNT_UNIQUES: begin
        next_state = COMPARE;
      end

      COMPARE: begin
        next_state = DONE;
      end

      DONE: begin
        // Wait for start to deassert and reassert for next operation
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Combinational logic to count unique bytes for each word
  function automatic [3:0] count_unique_bytes (input logic [63:0] w);
    // Extract bytes
    logic [7:0] b[7:0];
    logic [7:0] i, j;
    logic       dup;
    logic [3:0] cnt;
  begin
    b[7] = w[63:56];
    b[6] = w[55:48];
    b[5] = w[47:40];
    b[4] = w[39:32];
    b[3] = w[31:24];
    b[2] = w[23:16];
    b[1] = w[15:8];
    b[0] = w[7:0];

    cnt = 4'd0;
    for (i = 0; i < 8; i++) begin
      dup = 1'b0;
      for (j = 0; j < i; j++) begin
        if (b[i] == b[j]) begin
          dup = 1'b1;
        end
      end
      if (!dup)
        cnt = cnt + 4'd1;
    end
    return cnt;
  end
  endfunction

  // Parallel unique count for all words (used in COUNT_UNIQUES)
  always_comb begin
    if (state == COUNT_UNIQUES) begin
      unique_cnt[0] = count_unique_bytes(words[0]);
      unique_cnt[1] = count_unique_bytes(words[1]);
      unique_cnt[2] = count_unique_bytes(words[2]);
      unique_cnt[3] = count_unique_bytes(words[3]);
    end
  end

endmodule