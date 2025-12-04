module ski_path_finder (
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start computation
  input [1:0] num_cabins, // N (2-4 cabins)
  input [2:0] num_pistes, // M (0-6 pistes)
  input [287:0] adjacency_input, // flattened 4x4x32b Q16.16 matrix (cabins [1:0] × [1:0] → prob_fall[31:0])
  output reg [127:0] results, // 4×32b Q16.16 probabilities for k=0-3
  output reg done // high when results valid
);

  // Matrix is 4x4 of 32-bit Q16.16 fall probabilities.
  // Bit mapping: [i*128 + j*32 +: 32] -> P_fall[i][j] (little-endian 32-bit words)
  // Only the top-left NxN (N = num_cabins) is valid.
  localparam int MAT_SZ = 4;
  localparam int STEP = 4; // compute 4 steps for walks_used=0..3
  localparam logic [31:0] ONE = 32'h0001_0000; // Q16.16 1.0

  // State storage
  logic [31:0] state [MAT_SZ];
  logic [31:0] next_state [MAT_SZ];
  logic [31:0] fall [MAT_SZ][MAT_SZ];
  logic [31:0] surv [MAT_SZ][MAT_SZ]; // survival = 1 - fall

  logic [4:0] cycle;
  logic started_reg;
  logic [1:0] walks_used;
  logic walking_used;

  // Parse adjacency_input: fall and survival matrices
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < MAT_SZ; i++) begin
        for (int j = 0; j < MAT_SZ; j++) begin
          fall[i][j] <= 32'h0;
          surv[i][j] <= ONE; // default: no edge => cannot arrive via ski
        end
      end
    end else begin
      for (int i = 0; i < MAT_SZ; i++) begin
        for (int j = 0; j < MAT_SZ; j++) begin
          fall[i][j] <= adjacency_input[i*128 + j*32 +: 32];
          // Q16.16 subtraction with saturation at 0 (no negative survival)
          if (fall[i][j] <= ONE) surv[i][j] <= ONE - fall[i][j];
          else                   surv[i][j] <= 32'h0;
        end
      end
    end
  end

  // Cycle and start tracking
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle <= 5'd0;
      started_reg <= 1'b0;
    end else begin
      started_reg <= start;
      if (start) cycle <= 5'd1;
      else if (cycle != 5'd0) cycle <= cycle + 5'd1;
    end
  end

  // DP state update on each cycle
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < MAT_SZ; i++) state[i] <= 32'h0;
      next_state <= '{default:32'h0};
      done <= 1'b0;
    end else begin
      if (start) begin
        // k = 0
        walking_used <= 1'b0;
        for (int i = 0; i < MAT_SZ; i++) begin
          if (i < num_cabins) state[i] <= ONE; else state[i] <= 32'h0;
        end
        done <= 1'b0;
      end else if (cycle >= 1 && cycle < STEP) begin
        // k = cycle
        for (int j = 0; j < MAT_SZ; j++) next_state[j] <= 32'h0;
        for (int i = 0; i < MAT_SZ; i++) begin
          if (i >= num_cabins) continue;
          if (state[i] == 32'h0) continue;
          for (int j = 0; j < MAT_SZ; j++) begin
            if (j >= num_cabins) continue;
            // Walk (reverse allowed) with 0% fall
            next_state[j] <= next_state[j] | state[i];
            // Ski with survival probability if an edge exists (fall != max Q16.16)
            if (fall[i][j] != 32'hFFFF_FFFF) begin
              // Multiply Q16.16: saturate at ONE
              next_state[j] <= mult_q16(state[i], surv[i][j]);
            end
          end
        end
        for (int j = 0; j < MAT_SZ; j++) state[j] <= next_state[j];
        walking_used <= 1'b1;
        done <= 1'b0;
      end else if (cycle == STEP) begin
        // Finalize results for k=0..3
        walks_used <= (walking_used ? 2'd3 : 2'd0);
        // k = 0: stored in state at cycle 0 (after start) -> capture now
        results[31:0] <= (num_cabins >= 1) ? state[0] : 32'h0;
        // k = 1,2,3: we did 3 relaxation cycles (1->3); read back stored 'state' for each
        // Note: 'state' is from previous cycle; after last relax it holds k=3.
        results[63:32]   <= (num_cabins >= 2) ? state[1] : 32'h0;
        results[95:64]   <= (num_cabins >= 3) ? state[2] : 32'h0;
        results[127:96]  <= (num_cabins >= 4) ? state[3] : 32'h0;
        done <= 1'b1;
        cycle <= 5'd0; // clear counter for next run
      end else begin
        done <= 1'b0;
      end
    end
  end

  // Q16.16 multiply with saturation at 1.0
  function [31:0] mult_q16(input [31:0] a, input [31:0] b);
    logic [47:0] prod;
    logic [31:0] out;
    prod = $signed({1'b0, a}) * $signed({1'b0, b});
    out = prod[47:16];
    if (out > ONE) out = ONE;
    mult_q16 = out;
  endfunction

endmodule