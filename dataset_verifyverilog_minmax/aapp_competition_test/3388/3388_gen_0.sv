module julia_betting(
  input clk,
  input rst_n,
  input start,
  input [2:0] n, // Max 8 people (3 bits)
  input [7:0] julia_score,
  input [63:0] p_scores, // Packed 8x8-bit scores (MSB first)
  output reg [7:0] k,
  output reg done
);
  // Internal storage
  reg [7:0] s_julia;
  reg [7:0] scores [0:7]; // Fixed array for up to 7 opponents (descending order)
  reg [7:0] s_scores [0:7];
  reg [7:0] sum_distances [0:6];

  // State machine
  reg [2:0] state, next_state;
  localparam IDLE = 3'b000;
  localparam UNPACK = 3'b001;
  localparam SORT = 3'b010;
  localparam CALC = 3'b011;
  localparam DONE = 3'b100;

  // Counters
  reg [3:0] sort_inner;      // 0..3 (4 swaps per pass)
  reg [3:0] sort_outer;      // 0..6 (max 6 passes for 7 elements)
  reg [3:0] sort_i;          // 0..6 (0..n-2)
  reg [3:0] calc_i;          // 0..6 (0..n-2)
  reg [8:0] total;           // up to 7*255 = 1785, fits in 11 bits; using 9 bits to be safe
  reg [7:0] pack_idx;        // 0..7
  reg [2:0] active_n;        // n-1

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  // Next-state logic
  always @(*) begin
    case (state)
      IDLE:   next_state = start ? UNPACK : IDLE;
      UNPACK: next_state = SORT;
      SORT: begin
        if (sort_outer == 4'd7) next_state = CALC; // all passes done (or n-1=0)
        else next_state = SORT;
      end
      CALC:   next_state = DONE;
      DONE:   next_state = start ? UNPACK : IDLE;
      default: next_state = IDLE;
    endcase
  end

  // FSM actions and datapath
  always @(posedge clk) begin
    // Default: keep previous values (some will be reset in IDLE)
    if (state == IDLE) begin
      done <= 1'b0;
      k <= 8'd0;
      total <= 9'd0;
      sort_inner <= 4'd0;
      sort_outer <= 4'd0;
      sort_i <= 4'd0;
      calc_i <= 4'd0;
      pack_idx <= 8'd0;
      active_n <= 3'd0;
    end
    else if (state == UNPACK) begin
      s_julia <= julia_score; // capture for this session
      active_n <= (n == 3'd0) ? 3'd0 : (n - 3'd1); // number of opponents
      // Read packed p_scores, MSB first: bit indices [63:56] -> idx 0
      pack_idx <= 8'd0;
      // Pre-clear top 7 entries (for safety when n < 7)
      scores[0] <= 8'd0;
      scores[1] <= 8'd0;
      scores[2] <= 8'd0;
      scores[3] <= 8'd0;
      scores[4] <= 8'd0;
      scores[5] <= 8'd0;
      scores[6] <= 8'd0;
    end
    else if (state == SORT) begin
      // Bubble-sort up to 7 elements (max opponents)
      // Shift scores into s_scores during first cycle of SORT
      if (sort_outer == 4'd0 && sort_inner == 4'd0) begin
        if (pack_idx < 7) begin
          s_scores[pack_idx] <= p_scores[63 - (pack_idx * 8) -: 8];
          pack_idx <= pack_idx + 8'd1;
          sort_inner <= 4'd0; // keep inner at 0 while loading
          sort_outer <= 4'd0; // stay on pass 0 during loading
        end else begin
          // Start sorting: ensure s_scores[0..active_n] valid; others can be 0
          sort_inner <= 4'd0;
          sort_outer <= 4'd0;
        end
      end else begin
        // Perform one compare-swap per cycle
        if (sort_outer <= active_n) begin
          if (sort_inner < (active_n - sort_outer)) begin
            if (s_scores[sort_inner] < s_scores[sort_inner + 1]) begin
              s_scores[sort_inner]     <= s_scores[sort_inner + 1];
              s_scores[sort_inner + 1] <= s_scores[sort_inner];
            end
            sort_inner <= sort_inner + 4'd1;
          end else begin
            sort_inner <= 4'd0;
            sort_outer <= sort_outer + 4'd1;
          end
        end else begin
          // Sorting finished
          sort_outer <= 4'd7; // Mark done
        end
      end
    end
    else if (state == CALC) begin
      // Compute prefix sums sum_distances and final k
      if (calc_i == 3'd0) begin
        // Initialize prefix sum and total
        sum_distances[0] <= 8'd0;
        total <= 9'd0;
        calc_i <= 3'd1;
        sort_i <= 3'd1; // start with sum_distances[1]
      end else if (sort_i <= active_n) begin
        // Accumulate sum of sorted scores from high to low (descending)
        // sum_distances[i] = sum_{j=0}^{i-1} s_scores[j]
        sum_distances[sort_i] <= sum_distances[sort_i - 1] + s_scores[sort_i - 1];
        sort_i <= sort_i + 3'd1;
      end else if (calc_i <= active_n) begin
        // Process each opponent i (i from 0 to active_n-1)
        // other_scores[i] = s_scores[i]
        // if (julia_score - other_scores[i]) <= sum_distances[i+1]
        //   total += floor((sum_distances[i+1] - (julia_score - other_scores[i]) + 1) / 2)
        // else
        //   total += julia_score - other_scores[i]
        if ((s_julia >= s_scores[calc_i - 1]) && 
            ((s_julia - s_scores[calc_i - 1]) <= sum_distances[calc_i])) begin
          // Use: floor((A + 1) / 2) = (A >> 1) + (A[0])
          total <= total + ((sum_distances[calc_i] - (s_julia - s_scores[calc_i - 1]) + 8'd1) >> 1) 
                            + ((sum_distances[calc_i] - (s_julia - s_scores[calc_i - 1]) + 8'd1) & 8'd1);
        end else begin
          total <= total + (s_julia - s_scores[calc_i - 1]);
        end
        calc_i <= calc_i + 3'd1;
      end else begin
        k <= total;
        done <= 1'b1;
      end
    end else if (state == DONE) begin
      // Hold done high until next start; k already valid
      done <= 1'b1;
    end
  end
endmodule