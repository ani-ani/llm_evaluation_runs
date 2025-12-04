module coin_change(
  input clk,
  input rst_n,
  input start,
  input [2:0] num_coins,
  input [7:0] a [0:6],
  input [7:0] b [0:7],
  input [7:0] m,
  output reg [29:0] result,
  output reg done
);

  localparam MOD = 1000000007;
  localparam MAX_VAL = 2040;  // Sum b[i] = 2040 max

  typedef enum {IDLE, PROCESSING, DONE} state_e;
  state_e state, next_state;

  reg [10:0] count_cycles;
  reg [2:0] coin_idx;
  reg [10:0] dp_idx, compress_idx;
  reg [10:0] j, k;
  reg processing_comp;

  logic [29:0] d_current [0:MAX_VAL];
  logic [29:0] d_next [0:MAX_VAL];

  // FSM state transition
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // FSM next state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: if (start) next_state = PROCESSING;
      PROCESSING: if (&{coin_idx == num_coins, count_cycles == m}) next_state = DONE;
      DONE: next_state = IDLE;
    endcase
  end

  // Control signals and processing
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      result <= 0;
      count_cycles <= 0;
      coin_idx <= 0;
      processing_comp <= 0;
      compress_idx <= 0;
      j <= 0;
      k <= 0;
      // Initialize DP array
      for (int i = 0; i <= MAX_VAL; i++) begin
        d_current[i] <= (i == 0) ? 30'd1 : 30'd0;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          result <= 0;
          count_cycles <= 0;
          coin_idx <= 0;
          if (start) begin
            // Reset DP array when starting
            for (int i = 0; i <= MAX_VAL; i++) begin
              d_current[i] <= (i == 0) ? 30'd1 : 30'd0;
            end
          end
        end

        PROCESSING: begin
          count_cycles <= count_cycles + 1;

          // Process current coin
          if (!processing_comp && coin_idx != 0 && a[coin_idx-1] != 1) begin
            // Compression phase for coin_idx-1
            d_next[compress_idx] = d_current[compress_idx];
            if (compress_idx > 0) begin
              d_next[compress_idx] = (d_current[compress_idx] + d_next[compress_idx - 1]) % MOD;
            end
            d_current[compress_idx] <= d_next[compress_idx];
            if (compress_idx == MAX_VAL) begin
              processing_comp <= 1;
              compress_idx <= 0;
            end else begin
              compress_idx <= compress_idx + 1;
            end
          end else begin
            // Convolution phase with coin supply limit b[coin_idx]
            if (j <= MAX_VAL) begin
              d_next[j] = d_current[j];
              if (j >= (coin_idx == 0 ? 1 : a[coin_idx-1])) begin
                for (int i = 1; i <= b[coin_idx]; i++) begin
                  logic [10:0] prev_idx = j - (coin_idx == 0 ? 1 : a[coin_idx-1])*i;
                  if (prev_idx >= 0 && prev_idx <= MAX_VAL) begin
                    d_next[j] = (d_next[j] + d_current[prev_idx]) % MOD;
                  end
                end
              end
              d_current[j] <= d_next[j];
              j <= j + 1;
            end else begin
              j <= 0;
              coin_idx <= coin_idx + 1;
              processing_comp <= 0;
              if (coin_idx == num_coins - 1) begin
                // All coins processed
              end
            end
          end
        end

        DONE: begin
          done <= 1'b1;
          result <= d_current[m] % MOD;
        end
      endcase
    end
  end
endmodule