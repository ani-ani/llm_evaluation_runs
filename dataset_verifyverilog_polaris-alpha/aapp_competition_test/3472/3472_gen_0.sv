module warlord_region_calc(
  input              clk,
  input              rst_n,
  input              start,
  input       [2:0]  W,
  input       [2:0]  N_lines,
  input       [15:0] lines [0:7][3:0],
  output reg  [2:0]  k,
  output reg         done
);

  // States
  typedef enum logic [1:0] {
    IDLE        = 2'b00,
    PROCESSING  = 2'b01,
    DONE_ST     = 2'b10
  } state_t;

  state_t state, next_state;

  // Registered storage for directions: {dx[16:0], dy[16:0]}
  reg  signed [16:0] dir_dx [0:7];
  reg  signed [16:0] dir_dy [0:7];
  reg                dir_valid [0:7];

  reg  [2:0]  idx;          // current cycle index (0-7)
  reg  [3:0]  D;            // unique directions count (0-8)
  reg         start_d;

  // W latched at start for stability during processing
  reg  [2:0]  W_latched;

  // Input line components (combinational wires from array)
  wire [15:0] x1 = lines[idx][0];
  wire [15:0] y1 = lines[idx][1];
  wire [15:0] x2 = lines[idx][2];
  wire [15:0] y2 = lines[idx][3];

  // Current dx, dy as signed for computation
  wire signed [16:0] cur_dx = $signed({1'b0, x2}) - $signed({1'b0, x1});
  wire signed [16:0] cur_dy = $signed({1'b0, y2}) - $signed({1'b0, y1});

  // Check if current line index is within N_lines
  wire        use_line = (idx < N_lines);

  // Combinational unique-direction detection relative to previous valid directions
  integer j;
  reg     is_duplicate;

  always @* begin
    is_duplicate = 1'b0;
    if (use_line) begin
      // If direction is zero vector, treat as valid and comparable (still a direction entry)
      // Compare with all prior stored unique directions
      for (j = 0; j < idx; j = j + 1) begin
        if (dir_valid[j]) begin
          // cross_i_j = dx_i*dy_j - dy_i*dx_j
          // Here i is current, j is stored
          // equal direction if cross == 0
          if (($signed(cur_dx) * $signed(dir_dy[j])) == ($signed(cur_dy) * $signed(dir_dx[j]))) begin
            is_duplicate = 1'b1;
          end
        end
      end
    end
  end

  // Next state logic
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = PROCESSING;
      end

      PROCESSING: begin
        if (idx == 3'd7)
          next_state = DONE_ST;
      end

      DONE_ST: begin
        // done is 1 for this cycle, then go back to IDLE
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      idx        <= 3'd0;
      D          <= 4'd0;
      done       <= 1'b0;
      k          <= 3'd0;
      W_latched  <= 3'd0;
      start_d    <= 1'b0;
      for (j = 0; j < 8; j = j + 1) begin
        dir_dx[j]   <= 17'sd0;
        dir_dy[j]   <= 17'sd0;
        dir_valid[j]<= 1'b0;
      end
    end else begin
      state   <= next_state;
      start_d <= start;
      done    <= 1'b0; // default, may be set in DONE_ST

      case (state)
        IDLE: begin
          idx <= 3'd0;
          D   <= 4'd0;
          // Clear direction table
          for (j = 0; j < 8; j = j + 1) begin
            dir_dx[j]    <= 17'sd0;
            dir_dy[j]    <= 17'sd0;
            dir_valid[j] <= 1'b0;
          end
          if (start && !start_d) begin
            W_latched <= W;
          end
        end

        PROCESSING: begin
          // For each cycle, process line idx if within N_lines
          if (use_line) begin
            // Determine if new unique direction
            if (!is_duplicate) begin
              dir_dx[idx]    <= cur_dx;
              dir_dy[idx]    <= cur_dy;
              dir_valid[idx] <= 1'b1;
              D              <= D + 1'b1;
            end else begin
              dir_dx[idx]    <= dir_dx[idx];
              dir_dy[idx]    <= dir_dy[idx];
              dir_valid[idx] <= 1'b0;
            end
          end else begin
            // Beyond N_lines: no new directions
            dir_dx[idx]    <= 17'sd0;
            dir_dy[idx]    <= 17'sd0;
            dir_valid[idx] <= 1'b0;
          end

          // Increment index up to 7
          if (idx != 3'd7)
            idx <= idx + 3'd1;
        end

        DONE_ST: begin
          // Compute regions and k using final D
          // R = 2 * D
          // k = (R >= W_latched) ? 0 : ((W_latched - R + 1) / 2)
          // Compute in wider signed/unsigned safely
          // D max 8 => R max 16, W_latched max 7
          begin
            reg [4:0] R;
            reg [4:0] diff;
            R = {1'b0, D} << 1; // 2*D
            if (R >= W_latched) begin
              k <= 3'd0;
            end else begin
              diff = W_latched - R + 5'd1;
              k <= diff[4:1]; // divide by 2
            end
          end
          done <= 1'b1;
          idx  <= 3'd0;
        end

        default: begin
          // Should not occur, reset-like behavior
          idx  <= 3'd0;
          D    <= 4'd0;
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule