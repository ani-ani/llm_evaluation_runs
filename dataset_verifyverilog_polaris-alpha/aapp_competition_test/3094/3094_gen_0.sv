module permutation_square_count(
  input clk, // Clock signal
  input rst_n, // Active-low reset
  input start, // Start computation
  input [2:0] n, // Permutation size (1-8)
  input [2:0] t_0, // Element 1 (chair assignments)
  input [2:0] t_1, // Element 2
  input [2:0] t_2, // Element 3
  input [2:0] t_3, // Element 4
  input [2:0] t_4, // Element 5
  input [2:0] t_5, // Element 6
  input [2:0] t_6, // Element 7
  input [2:0] t_7, // Element 8
  output reg [31:0] result, // Computed count (mod 1e9+7)
  output reg done // High when computation complete
);

  // Local parameters
  localparam MOD = 32'd1000000007;

  // State encoding
  localparam IDLE        = 3'd0;
  localparam INIT        = 3'd1;
  localparam FIND_NEXT   = 3'd2;
  localparam FOLLOW_CYCLE= 3'd3;
  localparam APPLY_CYCLE = 3'd4;
  localparam DONE_STATE  = 3'd5;

  reg [2:0] state, next_state;

  // Internal permutation storage
  reg [2:0] perm [0:7];

  // Visited flags
  reg visited [0:7];

  // Indices and counters
  reg [3:0] idx;           // for scanning elements (0..7)
  reg [2:0] cur;           // current node in cycle
  reg [3:0] cycle_len;     // length of current cycle

  // Control flags
  reg processing_cycle;    // high while traversing a cycle

  // Combinational next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT;
      end
      INIT: begin
        next_state = FIND_NEXT;
      end
      FIND_NEXT: begin
        if (idx >= n) begin
          next_state = DONE_STATE;
        end else if (!visited[idx]) begin
          next_state = FOLLOW_CYCLE;
        end else begin
          next_state = FIND_NEXT;
        end
      end
      FOLLOW_CYCLE: begin
        // Remain in FOLLOW_CYCLE until cycle completes (handled sequentially)
        if (!processing_cycle) begin
          next_state = APPLY_CYCLE;
        end else begin
          next_state = FOLLOW_CYCLE;
        end
      end
      APPLY_CYCLE: begin
        next_state = FIND_NEXT;
      end
      DONE_STATE: begin
        // stay done until reset or new start; here stay
        next_state = DONE_STATE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      result  <= 32'd0;
      done    <= 1'b0;
      idx     <= 4'd0;
      cur     <= 3'd0;
      cycle_len <= 4'd0;
      processing_cycle <= 1'b0;
      // clear visited
      for (i = 0; i < 8; i = i + 1) begin
        visited[i] <= 1'b0;
        perm[i]    <= 3'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done   <= 1'b0;
          result <= result; // hold
          if (start) begin
            // load permutation inputs
            perm[0] <= t_0;
            perm[1] <= t_1;
            perm[2] <= t_2;
            perm[3] <= t_3;
            perm[4] <= t_4;
            perm[5] <= t_5;
            perm[6] <= t_6;
            perm[7] <= t_7;
          end
        end

        INIT: begin
          // initialize visited, counters, result
          for (i = 0; i < 8; i = i + 1) begin
            visited[i] <= 1'b0;
          end
          idx              <= 4'd0;
          result           <= 32'd1;
          done             <= 1'b0;
          cycle_len        <= 4'd0;
          processing_cycle <= 1'b0;
        end

        FIND_NEXT: begin
          if (idx < n) begin
            if (visited[idx]) begin
              // move to next index
              idx <= idx + 4'd1;
            end else begin
              // start new cycle from idx
              cur <= idx[2:0];
              cycle_len <= 4'd0;
              processing_cycle <= 1'b1;
              // next_state will move to FOLLOW_CYCLE
            end
          end
        end

        FOLLOW_CYCLE: begin
          if (processing_cycle) begin
            if (!visited[cur]) begin
              visited[cur] <= 1'b1;
              cycle_len <= cycle_len + 4'd1;
              cur <= perm[cur];
            end else begin
              // cycle complete when we reach visited node
              processing_cycle <= 1'b0;
            end
          end
        end

        APPLY_CYCLE: begin
          // apply contribution of cycle_len to result
          if (cycle_len != 0) begin
            if (cycle_len[0] == 1'b1) begin
              // odd length: multiply by len
              result <= (result * cycle_len) % MOD;
            end else begin
              // even length
              if ((cycle_len % 4) == 0) begin
                // len divisible by 4: multiply by len/2
                result <= (result * (cycle_len >> 1)) % MOD;
              end else begin
                // not divisible by 4: result becomes 0
                result <= 32'd0;
              end
            end
          end
          // move to next index after finishing this cycle
          idx <= idx + 4'd1;
        end

        DONE_STATE: begin
          done <= 1'b1;
          result <= result % MOD;
        end

        default: begin
          // should not occur; safe defaults
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule