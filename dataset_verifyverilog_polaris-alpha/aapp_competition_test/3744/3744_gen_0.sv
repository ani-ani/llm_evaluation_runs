module team_selector(
  input clk, // Clock input
  input rst_n, // Active-low reset
  input start, // Start computation
  input [7:0] a [0:7], // Programming skills (8 students)
  input [7:0] b [0:7], // Sports skills (8 students)
  output reg [10:0] max_strength, // Maximum total strength (11-bit)
  output reg [7:0] prog_team, // 1-hot encoded programming team
  output reg [7:0] sport_team, // 1-hot encoded sports team
  output reg done // High when computation complete
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE   = 2'b00,
    CALC   = 2'b01,
    OUTPUT = 2'b10
  } state_t;

  state_t state, next_state;

  // Internal registers for iteration
  reg [2:0] i, j, p, q;          // student indices (0..7)
  reg [5:0] comb_idx;            // combination counter (0..55)

  // Current/programming/sports masks and strength
  reg [7:0] cur_prog_mask;
  reg [7:0] cur_sport_mask;
  reg [10:0] cur_strength;

  reg [7:0] best_prog_mask;
  reg [7:0] best_sport_mask;
  reg [10:0] best_strength;

  // Next-value registers for sequential update
  reg [2:0] next_i, next_j, next_p, next_q;
  reg [5:0] next_comb_idx;
  reg [7:0] next_best_prog_mask;
  reg [7:0] next_best_sport_mask;
  reg [10:0] next_best_strength;

  // FSM sequential block
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      max_strength <= 11'd0;
      prog_team <= 8'd0;
      sport_team <= 8'd0;
      done <= 1'b0;
      i <= 3'd0;
      j <= 3'd1;
      p <= 3'd0;
      q <= 3'd1;
      comb_idx <= 6'd0;
      best_prog_mask <= 8'd0;
      best_sport_mask <= 8'd0;
      best_strength <= 11'd0;
    end else begin
      state <= next_state;

      i <= next_i;
      j <= next_j;
      p <= next_p;
      q <= next_q;
      comb_idx <= next_comb_idx;

      best_prog_mask <= next_best_prog_mask;
      best_sport_mask <= next_best_sport_mask;
      best_strength <= next_best_strength;

      // Outputs updated only in OUTPUT state logic (below via next-state calc)
      if (next_state == OUTPUT) begin
        max_strength <= next_best_strength;
        prog_team <= next_best_prog_mask;
        sport_team <= next_best_sport_mask;
        done <= 1'b1;
      end else if (next_state == IDLE) begin
        // Clear done when returning to IDLE
        done <= 1'b0;
      end
    end
  end

  // Function: generate next lexicographic 2-combination for N=8
  function automatic void next_pair(
    input  [2:0] ci,
    input  [2:0] cj,
    output [2:0] ni,
    output [2:0] nj,
    output       wrapped
  );
    reg [2:0] ti, tj;
    reg w;
    begin
      ti = ci;
      tj = cj;
      w = 1'b0;
      if (tj < 3'd7) begin
        tj = tj + 3'd1;
      end else begin
        if (ti < 3'd6) begin
          ti = ti + 3'd1;
          tj = ti + 3'd1;
        end else begin
          // wrap after last pair (6,7)
          ti = 3'd0;
          tj = 3'd1;
          w = 1'b1;
        end
      end
      ni = ti;
      nj = tj;
      wrapped = w;
    end
  endfunction

  // Combinational next-state and combination evaluation
  always @* begin
    // Defaults
    next_state = state;

    next_i = i;
    next_j = j;
    next_p = p;
    next_q = q;
    next_comb_idx = comb_idx;

    next_best_prog_mask = best_prog_mask;
    next_best_sport_mask = best_sport_mask;
    next_best_strength = best_strength;

    cur_prog_mask = 8'd0;
    cur_sport_mask = 8'd0;
    cur_strength = 11'd0;

    case (state)
      IDLE: begin
        if (start) begin
          // Initialize search
          next_i = 3'd0;
          next_j = 3'd1;
          next_p = 3'd0;
          next_q = 3'd1;
          next_comb_idx = 6'd0;
          next_best_prog_mask = 8'd0;
          next_best_sport_mask = 8'd0;
          next_best_strength = 11'd0;
          next_state = CALC;
        end
      end

      CALC: begin
        // Evaluate one (prog pair, sport pair) combination per cycle
        // Current programming team mask
        cur_prog_mask = (8'b1 << i) | (8'b1 << j);

        // Ensure sports pair is disjoint; if not, skip but still advance pairs
        if (!(((8'b1 << p) | (8'b1 << q)) & cur_prog_mask)) begin
          // Valid disjoint sports pair
          cur_sport_mask = (8'b1 << p) | (8'b1 << q);

          // Compute strength: sum of selected programming skills + sports skills
          cur_strength = a[i] + a[j] + b[p] + b[q];

          // Track maximum
          if (cur_strength > next_best_strength) begin
            next_best_strength = cur_strength;
            next_best_prog_mask = cur_prog_mask;
            next_best_sport_mask = cur_sport_mask;
          end
        end

        // Advance sports pair (p,q); when wrapped, advance prog pair (i,j)
        begin
          logic wrap_s;
          logic wrap_p_all;
          logic [2:0] np1, nq1;
          logic [2:0] ni1, nj1;

          // Next sports pair
          next_pair(p, q, np1, nq1, wrap_s);
          next_p = np1;
          next_q = nq1;

          wrap_p_all = 1'b0;

          if (wrap_s) begin
            // Completed all sports pairs for this programming pair; move to next programming pair
            next_pair(i, j, ni1, nj1, wrap_p_all);
            next_i = ni1;
            next_j = nj1;
          end

          // Increment overall combination counter only while not done
          if (!wrap_p_all) begin
            next_comb_idx = comb_idx + 6'd1;
          end

          // If all programming pairs completed (wrap_p_all), move to OUTPUT
          if (wrap_p_all) begin
            next_state = OUTPUT;
          end
        end
      end

      OUTPUT: begin
        // Hold the computed best result for one cycle, then return to IDLE
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule