module password_recovery (
  input clk,
  input rst_n,
  input start,
  input [7:0] s_chars [0:15],  // S string (max 16 chars)
  input [7:0] t_data [0:25][0:3], // T_a to T_z (26 letters, 4 chars each)
  input [2:0] K,              // Expansion steps (0-4)
  input [1:0] M,               // Number of queries (1-4)
  input [11:0] positions [0:3], // Query positions (12-bit each)

  output reg [7:0] results [0:3], // ASCII results for each query
  output reg done
);

  // State machine states
  typedef enum logic [1:0] { IDLE = 2'b00, PROCESS_QUERY = 2'b01, DECODE_LEVEL = 2'b10, DONE = 2'b11 } state_t;
  state_t state, next_state;

  // Iteration counters
  reg [1:0] q_idx;     // which query is being processed (0..3)
  reg [1:0] q_count;   // number of queries launched (0..M)
  reg [2:0] level;     // remaining levels to trace (0..K)
  reg [11:0] cur_pos;  // current position during traceback

  // Combinational intermediates
  reg [7:0] s_char;    // S character at cur_pos
  wire [7:0] t_char;   // character from T[char]
  wire [11:0] new_pos; // new position from T lookup
  reg [7:0] pos_idx;   // index within T[char] (0..3)

  // Determine S index: 12-bit positions are treated as 0..4095; mask to S range (0..15)
  assign s_char   = s_chars[cur_pos[3:0]];
  // t_data index uses lowercase letter from S: 'a'..'z'
  assign t_char   = t_data[s_char - 8'd97][pos_idx];
  assign new_pos  = {4'b0, t_char[3:0]}; // take low 4 bits as next position

  // State transition logic (sequential)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= IDLE;
      done     <= 1'b0;
      q_idx    <= 2'b0;
      q_count  <= 2'b0;
      level    <= 3'b0;
      cur_pos  <= 12'b0;
      pos_idx  <= 8'b0;
      results  <= '{default: 8'b0};
    end else begin
      state    <= next_state;
      // default keep values; updates in specific states below
      case (next_state)
        IDLE: begin
          done     <= 1'b0;
          q_idx    <= 2'b0;
          q_count  <= 2'b0;
          level    <= 3'b0;
          cur_pos  <= 12'b0;
          pos_idx  <= 8'b0;
          results  <= results; // keep
        end

        PROCESS_QUERY: begin
          // Latch parameters for this query
          if (q_count == 2'b0) begin
            level   <= K;
            cur_pos <= positions[q_idx];
          end else begin
            level   <= K;
            cur_pos <= positions[q_idx];
          end
          pos_idx <= 8'b0;
          // If K == 0, we produce the result in this cycle
          if (K == 3'b0) begin
            results[q_idx] <= s_chars[positions[q_idx][3:0]];
          end
        end

        DECODE_LEVEL: begin
          // Combinational path sets s_char, t_char, new_pos, pos_idx
          // Update position and level
          cur_pos <= new_pos;
          level   <= level - 1;
          // If this was the last level, capture result
          if ((level - 1) == 3'b0) begin
            results[q_idx] <= s_chars[new_pos[3:0]];
          end
        end

        DONE: begin
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

  // Next-state and combinatorial decode
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        pos_idx = 8'b0;
        if (start) begin
          // Start processing; ensure M in [1,4]
          next_state = PROCESS_QUERY;
        end else begin
          next_state = IDLE;
        end
      end

      PROCESS_QUERY: begin
        // Launch query: if K > 0 go traceback; else result is ready (already captured above)
        if (K > 0) begin
          next_state = DECODE_LEVEL;
        end else begin
          // K == 0: result was already written in this cycle; move to next query or done
          if ((q_count + 1) == M) begin
            next_state = DONE;
          end else begin
            next_state = PROCESS_QUERY;
          end
        end
      end

      DECODE_LEVEL: begin
        // Use current level to find matching position in T[char]
        // Search for which of the 4 T[char] entries equals current position
        pos_idx = 8'b0;
        if (t_data[s_char - 8'd97][0] == cur_pos) pos_idx = 8'd0;
        else if (t_data[s_char - 8'd97][1] == cur_pos) pos_idx = 8'd1;
        else if (t_data[s_char - 8'd97][2] == cur_pos) pos_idx = 8'd2;
        else if (t_data[s_char - 8'd97][3] == cur_pos) pos_idx = 8'd3;
        else pos_idx = 8'd0; // should not happen with well-formed data

        if ((level - 1) == 3'b0) begin
          // After updating level to 0, either finish query or continue to next
          if ((q_count + 1) == M) begin
            next_state = DONE;
          end else begin
            next_state = PROCESS_QUERY;
          end
        end else begin
          next_state = DECODE_LEVEL;
        end
      end

      DONE: begin
        pos_idx = 8'b0;
        if (start) begin
          // Hold done=1; wait for start de-assert to begin new session
          next_state = DONE;
        end else begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  // Update counters in PROCESS_QUERY and DECODE_LEVEL transitions
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      q_idx   <= 2'b0;
      q_count <= 2'b0;
    end else begin
      case (next_state)
        IDLE: begin
          q_idx   <= 2'b0;
          q_count <= 2'b0;
        end
        PROCESS_QUERY: begin
          // On entry to PROCESS_QUERY, we are about to process q_idx
          q_count <= q_count + 1; // launched this query
          q_idx   <= q_idx;       // remains until we finish it
        end
        DECODE_LEVEL: begin
          q_idx   <= q_idx;
          q_count <= q_count;     // unchanged during traceback
        end
        DONE: begin
          q_idx   <= q_idx;
          q_count <= q_count;
        end
        default: ;
      endcase

      // When moving to next query after completing current one (from DECODE_LEVEL to PROCESS_QUERY)
      if (state == DECODE_LEVEL && next_state == PROCESS_QUERY) begin
        q_idx   <= q_idx + 1; // move to next query index
        q_count <= q_count;   // q_count already incremented when this query was launched
      end
    end
  end

endmodule
