module mission_assigner(
  input clk,
  input rst_n,
  input start,
  input reg [6:0] probabilities [0:3][0:3],
  output reg [31:0] max_prob,
  output reg done
);
  // State definitions
  localparam IDLE  = 2'b00;
  localparam CALC  = 2'b01;
  localparam DONE  = 2'b10;

  logic [1:0] state;
  logic [5:0] cycle_cnt;               // counts from 0 to 31
  logic [31:0] max_prob_reg;           // holds current maximum product

  // Permutation table: all 24 permutations of columns 0..3
  const logic [1:0] perm[24][4] = '{
    {2'd0,2'd1,2'd2,2'd3},
    {2'd0,2'd1,2'd3,2'd2},
    {2'd0,2'd2,2'd1,2'd3},
    {2'd0,2'd2,2'd3,2'd1},
    {2'd0,2'd3,2'd1,2'd2},
    {2'd0,2'd3,2'd2,2'd1},
    {2'd1,2'd0,2'd2,2'd3},
    {2'd1,2'd0,2'd3,2'd2},
    {2'd1,2'd2,2'd0,2'd3},
    {2'd1,2'd2,2'd3,2'd0},
    {2'd1,2'd3,2'd0,2'd2},
    {2'd1,2'd3,2'd2,2'd0},
    {2'd2,2'd0,2'd1,2'd3},
    {2'd2,2'd0,2'd3,2'd1},
    {2'd2,2'd1,2'd0,2'd3},
    {2'd2,2'd1,2'd3,2'd0},
    {2'd2,2'd3,2'd0,2'd1},
    {2'd2,2'd3,2'd1,2'd0},
    {2'd3,2'd0,2'd1,2'd2},
    {2'd3,2'd0,2'd2,2'd1},
    {2'd3,2'd1,2'd0,2'd2},
    {2'd3,2'd1,2'd2,2'd0},
    {2'd3,2'd2,2'd0,2'd1},
    {2'd3,2'd2,2'd1,2'd0}
  };

  // Combinatorial signals for the current permutation
  logic [5:0] perm_idx;                 // 0..31, only 0..23 are valid
  logic [6:0] p0, p1, p2, p3;           // extracted probabilities
  logic [31:0] a0, a1, a2, a3;          // probabilities scaled to Q16.16
  logic [63:0] prod01_full, prod012_full, final_full;
  logic [31:0] prod01, prod012, final_prod;

  // Map current cycle count to permutation index
  assign perm_idx = cycle_cnt;

  // Guard the array accesses: when perm_idx >= 24, use zero probabilities
  always_comb begin
    if (perm_idx < 24) begin
      p0 = probabilities[0][perm[perm_idx][0]];
      p1 = probabilities[1][perm[perm_idx][1]];
      p2 = probabilities[2][perm[perm_idx][2]];
      p3 = probabilities[3][perm[perm_idx][3]];
    end else begin
      p0 = 7'd0;
      p1 = 7'd0;
      p2 = 7'd0;
      p3 = 7'd0;
    end
  end

  // Convert each probability (0..100) to Q16.16 fixed point: p*65536/100
  assign a0 = (p0 * 65536) / 100;
  assign a1 = (p1 * 65536) / 100;
  assign a2 = (p2 * 65536) / 100;
  assign a3 = (p3 * 65536) / 100;

  // 32-bit fixed-point multiplications (Q16.16 * Q16.16 => Q32.32)
  // We compute the full 64‑bit product, then shift right 16 bits to keep Q16.16.
  assign prod01_full   = $unsigned(a0) * $unsigned(a1);
  assign prod01        = prod01_full >> 16;
  assign prod012_full  = $unsigned(prod01) * $unsigned(a2);
  assign prod012       = prod012_full >> 16;
  assign final_full    = $unsigned(prod012) * $unsigned(a3);
  assign final_prod    = final_full >> 16;

  // Sequential control logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      cycle_cnt  <= 6'd0;
      max_prob_reg <= 32'd0;
      max_prob   <= 32'd0;
      done       <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          cycle_cnt    <= 6'd0;
          max_prob_reg <= 32'd0;
          max_prob     <= 32'd0;
          done         <= 1'b0;
          if (start) state <= CALC;
        end
        CALC: begin
          // Advance cycle counter (max 32 cycles)
          if (cycle_cnt < 6'd31) cycle_cnt <= cycle_cnt + 1;

          // Update maximum if we are still within the 24 permutations
          if (cycle_cnt < 6'd24) begin
            if (final_prod > max_prob_reg) max_prob_reg <= final_prod;
          end

          // Output the current max each cycle (so it stabilises after 24 cycles)
          max_prob <= max_prob_reg;

          // After 32 cycles (cycle_cnt == 31) move to DONE and assert done
          if (cycle_cnt == 6'd31) begin
            state <= DONE;
            done  <= 1'b1;
          end
        end
        DONE: begin
          // Hold the final result and keep done asserted
          done  <= 1'b1;
          // max_prob already holds the final value
        end
      endcase
    end
  end
endmodule