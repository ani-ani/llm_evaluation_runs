module ice_cream_optimizer(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,         // 1..16 scoops
  input [1:0] k,         // 1..4 flavors
  input [8:0] a,         // cost per scoop (1..200)
  input [8:0] b,         // cone cost (1..200)
  input [8:0] t [0:3],   // tastiness of each flavor (9‑bit signed)
  input [8:0] u [0:3][0:3], // pairwise tastiness (9‑bit signed)
  output reg [31:0] max_ratio, // Q16.16 fixed‑point result
  output reg done        // high when computation finishes
);

  // ------------------------------------------------------------
  // Parameters and constants
  // ------------------------------------------------------------
  localparam COMBO_MEM_SIZE = 5000;          // enough for all combos (max 4845)
  localparam INT14_MAX = 14'h1FFF;           //  8191
  localparam INT14_MIN = -14'h2000;          // -8192

  // ------------------------------------------------------------
  // ROM containing all (c0,c1,c2,c3) with sum <= 16
  // ------------------------------------------------------------
  logic [19:0] combo_mem [0:COMBO_MEM_SIZE-1]; // 5 bits per flavor, packed
  integer total_combos;
  initial begin
    integer i0,i1,i2,i3,idx;
    idx = 0;
    for (i0 = 0; i0 <= 16; i0++) begin
      for (i1 = 0; i1 <= 16; i1++) begin
        for (i2 = 0; i2 <= 16; i2++) begin
          for (i3 = 0; i3 <= 16; i3++) begin
            if (i0 + i1 + i2 + i3 <= 16) begin
              combo_mem[idx] = {i0[4:0], i1[4:0], i2[4:0], i3[4:0]};
              idx++;
            end
          end
        end
      end
    end
    total_combos = idx; // should be 4845 (including the (0,0,0,0) entry)
  end

  // ------------------------------------------------------------
  // Registers
  // ------------------------------------------------------------
  // max_tastiness[0] corresponds to s=1, max_tastiness[15] to s=16
  reg signed [13:0] max_tastiness [0:15];

  reg [31:0] combo_idx;
  reg [4:0] s_idx;           // current scoop count being processed (1..16)
  reg prev_start;
  reg done_reg;

  // State machine
  typedef enum bit [2:0] {IDLE, INIT, COMB_ITER, RATIO_CALC, DONE} state_t;
  state_t state, next_state;

  // Wires for current combo
  logic [4:0] c0, c1, c2, c3;
  logic [4:0] scoops;        // total scoops of this combo
  logic signed [15:0] tast;  // computed tastiness (temp)
  logic signed [13:0] tast_clamped; // clamped to 14‑bit

  // ------------------------------------------------------------
  // Combinational decoding of combo
  // ------------------------------------------------------------
  assign c0 = combo_mem[combo_idx][19:15];
  assign c1 = combo_mem[combo_idx][14:10];
  assign c2 = combo_mem[combo_idx][9:5];
  assign c3 = combo_mem[combo_idx][4:0];
  assign scoops = c0 + c1 + c2 + c3;

  // Compute tastiness for the current combo
  always_comb begin
    // base linear part
    tast = $signed(t[0]) * c0 + $signed(t[1]) * c1 + $signed(t[2]) * c2 + $signed(t[3]) * c3;

    // diagonal (same flavor) contributions
    for (int i = 0; i < 4; i++) begin
      int ci;
      case (i)
        0: ci = c0;
        1: ci = c1;
        2: ci = c2;
        default: ci = c3;
      endcase
      int comb = ci * (ci - 1) / 2; // C(ci,2)
      tast += $signed(u[i][i]) * comb;
    end

    // off‑diagonal contributions
    for (int i = 0; i < 4; i++) begin
      for (int j = i + 1; j < 4; j++) begin
        int ci, cj;
        case (i)
          0: ci = c0;
          1: ci = c1;
          2: ci = c2;
          default: ci = c3;
        endcase
        case (j)
          0: cj = c0;
          1: cj = c1;
          2: cj = c2;
          default: cj = c3;
        endcase
        tast += $signed(u[i][j]) * (ci * cj);
      end
    end

    // clamp to 14‑bit signed range
    if (tast > INT14_MAX)       tast_clamped = INT14_MAX;
    else if (tast < INT14_MIN)  tast_clamped = INT14_MIN;
    else                         tast_clamped = tast[13:0];
  end

  // ------------------------------------------------------------
  // State machine: sequential logic
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      done    <= 1'b0;
      max_ratio <= 32'h0;
      for (int i = 0; i < 16; i++) max_tastiness[i] <= -14'h2000; // minimal
      combo_idx  <= 0;
      s_idx      <= 1;
      prev_start <= 1'b0;
      done_reg   <= 1'b0;
    end else begin
      prev_start <= start;

      // Default next‑state for unassigned states
      next_state <= state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start && !prev_start) begin
            // start of a new computation
            next_state <= INIT;
          end
        end

        INIT: begin
          // reset DP registers
          for (int i = 0; i < 16; i++) max_tastiness[i] <= -14'h2000;
          max_ratio <= 32'h0;
          combo_idx <= 0;
          s_idx     <= 1;
          next_state <= COMB_ITER;
        end

        COMB_ITER: begin
          if (combo_idx < total_combos) begin
            // Process current combo
            if (scoops != 0 && scoops <= n) begin
              // update max_tastiness for this scoop count
              if (tast_clamped > max_tastiness[scoops-1]) begin
                max_tastiness[scoops-1] <= tast_clamped;
              end
            end
            combo_idx <= combo_idx + 1;
          end else begin
            // All combos processed, move to ratio phase
            next_state <= RATIO_CALC;
            s_idx <= 1;
          end
        end

        RATIO_CALC: begin
          if (s_idx <= n) begin
            // Compute ratio for scoop count s_idx
            if (max_tastiness[s_idx-1] > 0) begin
              // numerator = tastiness * 2^16 (unsigned)
              logic [31:0] numer;
              numer = $unsigned(max_tastiness[s_idx-1]) << 16;
              logic [11:0] denom;
              denom = a * s_idx + b; // 12‑bit max is 3400
              logic [31:0] ratio;
              ratio = numer / denom;
              if (ratio > max_ratio) begin
                max_ratio <= ratio;
              end
            end
            s_idx <= s_idx + 1;
          end else begin
            next_state <= DONE;
            done <= 1'b1;
          end
        end

        DONE: begin
          // stay here until start goes low, then return to IDLE
          done <= 1'b1;
          if (!start) begin
            next_state <= IDLE;
          end
        end

        default: next_state <= IDLE;
      endcase

      state <= next_state;
    end
  end

  // output assignment
  assign done = done_reg;

endmodule
