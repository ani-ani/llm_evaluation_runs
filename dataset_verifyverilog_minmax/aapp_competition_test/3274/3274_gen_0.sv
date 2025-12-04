module torpedo_avoidance (
  input clk,
  input rst_n,
  input start,
  input [3:0] n_seconds, // Total steps (2-8)
  input [2:0] m_ships,   // 0-4 ships
  input signed [4:0] ship_x1 [0:3], // 4 ships max (-8 to +8)
  input signed [4:0] ship_x2 [0:3],
  input [3:0] ship_y [0:3],
  output reg [1:0] path [0:7], // 8 steps max (2'b00:-, 2'b01:0, 2'b10:+)
  output reg done,
  output reg possible
);

  // Internal state and pipeline registers
  reg [3:0] steps_done;           // 0..8, counts when busy
  reg busy;                       // high while computing
  reg [3:0] saved_n;              // n_seconds saved on start
  reg [2:0] saved_m;              // m_ships saved on start
  reg prev_start;                 // edge detection

  // Save ship data on start (combinational read from memories)
  reg [3:0] s_y [0:3];
  reg signed [4:0] s_x1 [0:3];
  reg signed [4:0] s_x2 [0:3];

  // Pipeline: possible masks (shift register of 17-bit vectors, bits [-8..+8])
  // valid[0] is only valid after first compute cycle (step 0 done), so we keep a 9-deep register.
  reg [16:0] valid [0:8]; // valid[i] corresponds to positions at time i (i in 0..8)

  // Path chosen based on one arbitrary valid trajectory (2 bits per step; 0..7)
  reg [1:0] path_reg [0:7];

  // Indices and constants
  integer i, j, k, m;

  // Maintain 8-deep shift register for valid positions
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i <= 8; i = i + 1) valid[i] <= 17'b0;
    end else begin
      // shift all stages down by one, inject next stage at index 8 (computed this cycle)
      for (i = 0; i <= 7; i = i + 1) begin
        valid[i] <= valid[i+1];
      end
      // valid[8] will be assigned in the same block with compute logic
    end
  end

  // Edge detection for start
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) prev_start <= 1'b0;
    else        prev_start <= start;
  end

  // Main control and compute
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      steps_done <= 4'd0;
      busy       <= 1'b0;
      done       <= 1'b0;
      possible   <= 1'b0;
      // clear pipeline masks
      for (i = 0; i <= 8; i = i + 1) valid[i] <= 17'b0;
      // clear outputs
      for (i = 0; i < 8; i = i + 1) path[i] <= 2'b00;
      for (i = 0; i < 8; i = i + 1) path_reg[i] <= 2'b00;
      saved_n <= 4'd0;
      saved_m <= 3'd0;
      // clear saved ship registers
      for (i = 0; i < 4; i = i + 1) begin
        s_y[i]  <= 4'd0;
        s_x1[i] <= 5'd0;
        s_x2[i] <= 5'd0;
      end
    end else begin
      // default outputs
      done     <= 1'b0;
      possible <= 1'b0;

      if (!busy && start && !prev_start) begin
        // Start pulse: latch inputs and initialize
        busy       <= 1'b1;
        steps_done <= 4'd0;
        done       <= 1'b0;
        possible   <= 1'b0;
        saved_n    <= n_seconds;
        saved_m    <= m_ships;

        // Save ship data to avoid combinational read hazards in subsequent cycles
        for (k = 0; k < 4; k = k + 1) begin
          s_y[k]  <= ship_y[k];
          s_x1[k] <= ship_x1[k];
          s_x2[k] <= ship_x2[k];
        end

        // Initialize pipeline: at t=0, torpedo is at x=0 (index 8)
        valid[0] <= 17'b1 << 8; // bit index 8 is x=0
        for (i = 1; i <= 8; i = i + 1) valid[i] <= 17'b0;

        // Clear path register
        for (i = 0; i < 8; i = i + 1) path_reg[i] <= 2'b00;
        for (i = 0; i < 8; i = i + 1) path[i]      <= 2'b00;
      end else if (busy) begin
        // Compute one step per clock
        steps_done <= steps_done + 1;

        // Compute mask for next time step (t = steps_done)
        // Use previous mask valid[steps_done-1] (at t-1), produce new mask at index 8
        // valid[steps_done-1] only valid when steps_done >= 1 (we are in this branch so steps_done increased first)
        begin
          reg [16:0] prev_mask;
          prev_mask = valid[steps_done-1];
          // Expand: from each valid x in [-8..+8], next x can be {x-1, x, x+1} within bounds
          // Represented as 17-bit vector indexed by x+8 (0..16)
          reg [16:0] nxt; // next possible positions (at time steps_done)
          nxt = 17'b0;
          for (i = 0; i < 17; i = i + 1) begin
            if (prev_mask[i]) begin
              // candidate positions based on x in [-8..+8]
              // left (i-1)
              if (i > 0) nxt[i-1] = 1'b1;
              // stay (i)
              nxt[i] = 1'b1;
              // right (i+1)
              if (i < 16) nxt[i+1] = 1'b1;
            end
          end

          // Collision pruning for current time = steps_done (y == steps_done)
          // Keep only positions not inside any ship's horizontal segment at this y
          if (saved_m > 0) begin
            reg [16:0] keep;
            keep = 17'h1FFFF; // all ones, 17 bits
            for (j = 0; j < saved_m; j = j + 1) begin
              if (s_y[j] == steps_done) begin
                // ship occupies [x1..x2] inclusive on this y
                // Convert to 17-bit mask
                if (s_x1[j] <= s_x2[j]) begin
                  for (m = s_x1[j]; m <= s_x2[j]; m = m + 1) begin
                    if (m >= -8 && m <= 8) keep[m + 8] = 1'b0;
                  end
                end
              end
            end
            nxt = nxt & keep;
          end

          // Inject into pipeline tail (valid[8] will be shifted next cycle to valid[7])
          valid[8] <= nxt;
        end

        // Select a single path (greedy) as we go, if any positions remain possible
        // At time t, we choose the smallest x index that remains possible in valid[steps_done]
        if (|valid[steps_done]) begin
          // Find least-index set bit in valid[steps_done]
          for (i = 0; i < 17; i = i + 1) begin
            if (valid[steps_done][i]) begin
              // Determine how we got here from previous step
              // Action codes: 2'b00 = -, 2'b01 = 0, 2'b10 = +
              if (steps_done > 0) begin
                reg [16:0] prev_mask;
                prev_mask = valid[steps_done-1];
                // Prefer +1, 0, -1 in lexicographic order of resulting x (smallest i)
                if (i > 0 && prev_mask[i-1]) path_reg[steps_done-1] <= 2'b00; // came from left => we moved right (-)
                else if (prev_mask[i])       path_reg[steps_done-1] <= 2'b01; // stayed
                else if (i < 16 && prev_mask[i+1]) path_reg[steps_done-1] <= 2'b10; // came from right => we moved left (+)
                else                           path_reg[steps_done-1] <= 2'b01; // default
              end
              // If steps_done==0, we are filling path[0] based on the first move from t=0 to t=1
              if (steps_done == 0) begin
                if (i > 0) path_reg[0] <= 2'b00; // we moved right (so action was -)
                else       path_reg[0] <= 2'b01;
              end
              break;
            end
          end
        end

        // Completion check: results ready exactly n_seconds+1 cycles after start
        if (steps_done == (saved_n + 1)) begin
          done     <= 1'b1;
          possible <= (|valid[saved_n]) ? 1'b1 : 1'b0;
          // If possible, copy chosen path to outputs for steps 0..n_seconds-1
          if (|valid[saved_n]) begin
            for (i = 0; i < 8; i = i + 1) path[i] <= path_reg[i];
          end else begin
            // Not possible, keep outputs 0
            for (i = 0; i < 8; i = i + 1) path[i] <= 2'b00;
          end
          busy     <= 1'b0;
        end
      end
    end
  end
endmodule