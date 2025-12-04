module house_envy_solver (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [31:0] k,
  input [31:0] h0,
  input [31:0] h1,
  input [31:0] h2,
  input [31:0] h3,
  input [31:0] h4,
  input [31:0] h5,
  input [31:0] h6,
  input [31:0] h7,
  output reg [31:0] max_height,
  output reg done
);

  // State machine
  typedef enum logic [1:0] {S_IDLE = 2'b00, S_ITER = 2'b01, S_FINAL1 = 2'b10, S_DONE = 2'b11} state_t;
  state_t state, state_next;

  // Iteration and house index counters
  reg [6:0] iter;           // 0..99
  reg [2:0] h_idx;          // 0..n

  // Working house heights (Q16.16)
  reg [31:0] h_r [0:7];
  reg [31:0] h_next [0:7];

  // New height for current house (Q16.16)
  reg [31:0] new_h;

  // Final max pipeline
  reg [31:0] max_out_reg;

  // Control signals
  reg load_start, iter_inc, hidx_inc;

  // Helper: next h_idx with wrap to n (for readability)
  wire [2:0] h_idx_plus1 = (h_idx < n) ? (h_idx + 1) : 3'd0;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      iter  <= 7'd0;
      h_idx <= 3'd0;
      max_out_reg <= 32'd0;
      done <= 1'b0;
      max_height <= 32'd0;
      new_h <= 32'd0;
    end else begin
      // Defaults
      iter_inc <= 1'b0;
      hidx_inc <= 1'b0;
      load_start <= 1'b0;

      // State machine
      case (state)
        S_IDLE: begin
          // Load start of a new run
          if (start) begin
            load_start <= 1'b1;
            iter <= 7'd0;
            h_idx <= 3'd0;
            max_out_reg <= 32'd0; // will hold final max
            done <= 1'b0;
            state_next <= S_ITER;
          end else begin
            state_next <= S_IDLE;
          end
        end

        S_ITER: begin
          // Update current house (combinational path via new_h)
          if (h_idx < n) begin
            h_idx <= h_idx + 1;
            hidx_inc <= 1'b1;
          end else begin
            // Completed a full left-to-right pass over houses 0..n
            if (iter < 7'd99) begin
              iter <= iter + 1;
              iter_inc <= 1'b1;
              h_idx <= 3'd0;
            end else begin
              state_next <= S_FINAL1;
            end
          end
        end

        S_FINAL1: begin
          // Compute final max across all houses
          state_next <= S_DONE;
        end

        S_DONE: begin
          // Result valid, stay until next start or reset
          if (start) begin
            // Allow back-to-back runs
            load_start <= 1'b1;
            iter <= 7'd0;
            h_idx <= 3'd0;
            max_out_reg <= 32'd0;
            done <= 1'b0;
            state_next <= S_ITER;
          end else begin
            state_next <= S_DONE;
          end
        end

        default: state_next <= S_IDLE;
      endcase

      // Latch state
      state <= state_next;

      // Capture and update heights when load_start is asserted
      if (load_start) begin
        h_r[0] <= h0;
        h_r[1] <= h1;
        h_r[2] <= h2;
        h_r[3] <= h3;
        h_r[4] <= h4;
        h_r[5] <= h5;
        h_r[6] <= h6;
        h_r[7] <= h7;
      end else begin
        // Sequential update: commit computed next values
        h_r[0] <= h_next[0];
        h_r[1] <= h_next[1];
        h_r[2] <= h_next[2];
        h_r[3] <= h_next[3];
        h_r[4] <= h_next[4];
        h_r[5] <= h_next[5];
        h_r[6] <= h_next[6];
        h_r[7] <= h_next[7];
      end

      // Final max pipeline and done flag
      if (state == S_FINAL1) begin
        // Reduce across all houses (0..n)
        max_out_reg <= h_r[0];
        if (n >= 3'd1 && h_r[1] > max_out_reg) max_out_reg <= h_r[1];
        if (n >= 3'd2 && h_r[2] > max_out_reg) max_out_reg <= h_r[2];
        if (n >= 3'd3 && h_r[3] > max_out_reg) max_out_reg <= h_r[3];
        if (n >= 3'd4 && h_r[4] > max_out_reg) max_out_reg <= h_r[4];
        if (n >= 3'd5 && h_r[5] > max_out_reg) max_out_reg <= h_r[5];
        if (n >= 3'd6 && h_r[6] > max_out_reg) max_out_reg <= h_r[6];
        if (n >= 3'd7 && h_r[7] > max_out_reg) max_out_reg <= h_r[7];
      end else if (state == S_DONE) begin
        done <= 1'b1;
        max_height <= max_out_reg;
      end else begin
        done <= 1'b0;
      end
    end
  end

  // Combinational update of each house with Q16.16 arithmetic
  // new_h_i = max(h_i, (left + right)/2 + k)
  // sum left+right maintained over 33 bits before division by 2 (right shift)
  integer i;
  always @(*) begin
    // Default: next state equals current (no change)
    for (i = 0; i < 8; i++) h_next[i] = h_r[i];

    // Current indices
    h_next[h_idx] = h_r[h_idx];

    // Neighbor retrieval (signed Q16.16)
    if (h_idx == 3'd0) begin
      // left neighbor for house 0 is 0
      if (h_idx < n) begin
        // house 0 with valid right neighbor
        wire signed [31:0] left = 32'sd0;
        wire signed [31:0] right = h_r[h_idx + 1];
        // Maintain 33 bits for sum: sign-extend to 33 bits before adding
        wire signed [32:0] left33 = $signed({1'b0, left});
        wire signed [32:0] right33 = $signed({1'b0, right});
        wire signed [32:0] sum33 = left33 + right33;          // 33-bit sum
        wire signed [32:0] avg33 = sum33 >>> 1;              // (left+right)/2 (Q16.16)
        wire signed [32:0] cand33 = avg33 + $signed(k);      // add k, 33-bit
        wire signed [31:0] cand = cand33[31:0];
        new_h = (cand > $signed(h_r[h_idx])) ? cand : h_r[h_idx];
        h_next[h_idx] = new_h;
      end else begin
        // only house 0 exists (n == 0)
        h_next[0] = h_r[0];
      end
    end else if (h_idx < n) begin
      // General case: both neighbors exist
      wire signed [31:0] left = h_r[h_idx - 1];
      wire signed [31:0] right = h_r[h_idx + 1];
      wire signed [32:0] left33 = $signed({1'b0, left});
      wire signed [32:0] right33 = $signed({1'b0, right});
      wire signed [32:0] sum33 = left33 + right33;          // 33-bit sum
      wire signed [32:0] avg33 = sum33 >>> 1;              // (left+right)/2 (Q16.16)
      wire signed [32:0] cand33 = avg33 + $signed(k);      // add k
      wire signed [31:0] cand = cand33[31:0];
      new_h = (cand > $signed(h_r[h_idx])) ? cand : h_r[h_idx];
      h_next[h_idx] = new_h;
    end else begin
      // h_idx == n: right neighbor is 0
      wire signed [31:0] left = h_r[h_idx - 1];
      wire signed [31:0] right = 32'sd0;
      wire signed [32:0] left33 = $signed({1'b0, left});
      wire signed [32:0] right33 = $signed({1'b0, right});
      wire signed [32:0] sum33 = left33 + right33;          // 33-bit sum
      wire signed [32:0] avg33 = sum33 >>> 1;              // (left+right)/2 (Q16.16)
      wire signed [32:0] cand33 = avg33 + $signed(k);      // add k
      wire signed [31:0] cand = cand33[31:0];
      new_h = (cand > $signed(h_r[h_idx])) ? cand : h_r[h_idx];
      h_next[h_idx] = new_h;
    end
  end

endmodule
