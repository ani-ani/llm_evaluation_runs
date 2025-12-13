module queen_placement_calculator(
  input clk,
  input rst_n,
  input start,
  input [15:0] board_layout,  // Flattened 4x4 grid (1=usable, 0=broken)
  output reg [3:0] max_queens,
  output reg [15:0] num_ways,
  output reg done
);

  // State encoding
  localparam IDLE      = 2'b00;
  localparam PROCESS   = 2'b01;
  localparam FINISHED  = 2'b10;

  // Internal signals
  reg [1:0] state, state_next;
  reg [15:0] cfg, cfg_next;           // Current queen configuration under test
  reg [3:0] cur_max, cur_max_next;    // Current maximum queens found
  reg [15:0] cur_ways, cur_ways_next; // Number of ways achieving cur_max
  reg [4:0] count_ones;               // Queen count for current configuration
  reg conflict;                       // 1 if current configuration invalid (attack condition)

  // Distance-based bitwise attack checks
  // Each queen can attack another if:
  // - same row:           dr == 0
  // - same column:        dc == 0
  // - same diagonal:      abs(dr) == abs(dc)
  // We detect any attack between any two queens.
  // This is equivalent to "no pair of queens attack each other";
  // if there is no pairwise attack, there cannot be a 3-queen mutual-attack set.

  // Row-major index mapping:
  // bit k = row = k>>2, col = k&2'b11

  // Compute conflicts using combinational logic (uses current 'cfg')
  integer i, j, dr, dc;
  always @(*) begin
    conflict = 1'b0;
    if (cfg == 16'b0) begin
      conflict = 1'b0; // no queens, no conflicts
    end else begin
      for (i = 0; i < 16; i = i + 1) begin
        if (cfg[i]) begin
          for (j = i + 1; j < 16; j = j + 1) begin
            if (cfg[j]) begin
              dr = (i >> 2) - (j >> 2);
              dc = (i & 3) - (j & 3);
              if ((dr == 0) || (dc == 0) || ($abs(dr) == $abs(dc))) begin
                conflict = 1'b1;
                // No early-exit from combinatorial loop; conflict remains 1
              end
            end
          end
        end
      end
    end
  end

  // Count number of set bits in 'cfg' (combinational)
  always @(*) begin
    count_ones = 5'd0;
    for (i = 0; i < 16; i = i + 1) begin
      if (cfg[i]) count_ones = count_ones + 1'b1;
    end
  end

  // Sequential logic (synchronous reset, positive clk)
  always @(posedge clk) begin
    if (!rst_n) begin
      state     <= IDLE;
      cfg       <= 16'b0;
      cur_max   <= 4'd0;
      cur_ways  <= 16'b0;
      done      <= 1'b0;
    end else begin
      state     <= state_next;
      cfg       <= cfg_next;
      cur_max   <= cur_max_next;
      cur_ways  <= cur_ways_next;
      done      <= (state_next == FINISHED);
    end
  end

  // State machine next logic
  always @(*) begin
    // defaults
    state_next = state;
    cfg_next   = cfg;
    cur_max_next = cur_max;
    cur_ways_next = cur_ways;

    case (state)
      IDLE: begin
        if (start) begin
          cfg_next   = 16'b0;
          cur_max_next = 4'd0;
          cur_ways_next = 16'b0;
          state_next = PROCESS;
        end
      end

      PROCESS: begin
        // Evaluate current configuration 'cfg'
        if ((cfg & ~board_layout) == 16'b0) begin // all queens on usable cells
          if (!conflict) begin // no pairwise attacks => also no 3-queen mutual attack
            if (count_ones > cur_max) begin
              cur_max_next  = count_ones;
              cur_ways_next = 16'd1;
            end else if (count_ones == cur_max) begin
              cur_ways_next = cur_ways + 1'b1;
            end
          end
        end

        // Move to next configuration (2^16 possible patterns)
        if (cfg == 16'hFFFF) begin
          state_next = FINISHED;
        end else begin
          cfg_next = cfg + 1'b1;
        end
      end

      FINISHED: begin
        if (!start) begin
          state_next = IDLE; // allow re-start after 'start' deasserts
        end
        // otherwise stay finished until start deasserts
      end

      default: begin
        state_next = IDLE;
      end
    endcase
  end

  // Output assignments (registered for stable results after 'done')
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_queens <= 4'd0;
      num_ways   <= 16'd0;
    end else begin
      max_queens <= cur_max;
      num_ways   <= cur_ways;
    end
  end

endmodule
