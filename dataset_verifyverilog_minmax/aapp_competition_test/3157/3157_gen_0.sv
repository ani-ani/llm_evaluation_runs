module hash_word_counter(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // pulse high to start computation
  input [3:0] N, // word length (1-10)
  input [24:0] K, // target hash value (0 <= K < 2^M)
  input [4:0] M, // modulo exponent (6-25, MOD = 2^M)
  output reg [46:0] count, // number of valid words
  output reg done // high when computation complete
);

  // State machine states
  localparam IDLE = 2'd0;
  localparam INIT = 2'd1;
  localparam PROCESSING = 2'd2;
  localparam DONE = 2'd3;

  // State machine and counters
  reg [1:0] state;
  reg [3:0] char_pos; // 0 to N-1
  reg [31:0] state_counter; // 0 to (2^M * 26 - 1)
  reg [31:0] total_steps; // (2^M * 26)

  // DP table: using two memories for current and next
  // Max size 2^25 = 33,554,432 entries, each 47 bits
  // Note: For synthesis, this would be too large but meets functional spec
  reg [46:0] dp_current [0:33554431];
  reg [46:0] dp_next [0:33554431];
  reg current_mem; // 0: using dp_current, 1: using dp_next

  // Temporary values for computation
  reg [24:0] current_hash;
  reg [46:0] current_count;
  reg [5:0] letter; // 1 to 26
  reg [24:0] new_hash;
  reg [46:0] next_count;

  integer i; // for initialization

  // Calculate total steps for processing
  always @(*) begin
    total_steps = (32'd1 << M) * 26; // 2^M * 26
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      count <= 47'd0;
      char_pos <= 4'd0;
      state_counter <= 32'd0;
      current_mem <= 1'b0;
    end
    else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
            done <= 1'b0;
            char_pos <= 4'd0;
            state_counter <= 32'd0;
            current_mem <= 1'b0; // start with dp_current
          end
        end

        INIT: begin
          // Initialize DP table: only dp_current[0] = 1, rest 0
          // In actual implementation, this would need to be done across multiple cycles
          // For simplicity, we assume initialization happens in one cycle here
          if (current_mem == 1'b0) begin
            for (i = 0; i < (32'd1 << M); i = i + 1) begin
              dp_current[i] <= 47'd0;
            end
            dp_current[0] <= 47'd1;
          end
          else begin
            for (i = 0; i < (32'd1 << M); i = i + 1) begin
              dp_next[i] <= 47'd0;
            end
            dp_next[0] <= 47'd1;
          end
          state <= PROCESSING;
        end

        PROCESSING: begin
          if (state_counter < total_steps) begin
            // Process one state-letter pair per cycle
            current_hash = state_counter / 26; // integer division
            letter = (state_counter % 26) + 1; // 1 to 26
            
            // Read current count
            if (current_mem == 1'b0) begin
              current_count = dp_current[current_hash];
            end
            else begin
              current_count = dp_next[current_hash];
            end
            
            // Compute new hash: (current_hash * 33) XOR letter
            new_hash = ((current_hash * 33) ^ letter) & ((32'd1 << M) - 1);
            
            // Accumulate count
            if (current_mem == 1'b0) begin
              next_count = dp_next[new_hash] + current_count;
              dp_next[new_hash] <= next_count;
            end
            else begin
              next_count = dp_current[new_hash] + current_count;
              dp_current[new_hash] <= next_count;
            end
            
            state_counter <= state_counter + 1;
          end
          else begin
            // Finished processing current character position
            char_pos <= char_pos + 1;
            state_counter <= 32'd0;
            
            // Switch memories for next character
            current_mem <= ~current_mem;
            
            if (char_pos >= (N - 1)) begin
              state <= DONE;
            end
          end
        end

        DONE: begin
          // Final count is in dp[current_mem][K]
          if (current_mem == 1'b0) begin
            count <= dp_current[K];
          end
          else begin
            count <= dp_next[K];
          end
          done <= 1'b1;
          state <= IDLE; // return to idle after outputting result
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule