module bell_number(
  input        clk,
  input        rst_n,
  input  [3:0] n,
  input        start,
  output reg [31:0] result,
  output reg        done
);

  // State encoding
  localparam IDLE        = 3'd0;
  localparam INIT        = 3'd1;
  localparam COMPUTE_ROW = 3'd2;
  localparam COMPUTE_COL = 3'd3;
  localparam DONE_STATE  = 3'd4;

  reg [2:0] state, next_state;

  // Bell triangle: 8x8, 32 bits each
  reg [31:0] bell [0:7][0:7];

  // Indices and control
  reg [3:0] i, j;            // Row/column indices
  reg [3:0] cur_n;           // Latched n
  reg       start_d;         // For edge detection
  wire      start_pulse;

  assign start_pulse = start & ~start_d;

  integer r, c;

  // Sequential: state, regs, and memory updates
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= IDLE;
      start_d  <= 1'b0;
      done     <= 1'b0;
      result   <= 32'd0;
      cur_n    <= 4'd0;
      i        <= 4'd0;
      j        <= 4'd0;
      // Clear bell array
      for (r = 0; r < 8; r = r + 1) begin
        for (c = 0; c < 8; c = c + 1) begin
          bell[r][c] <= 32'd0;
        end
      end
    end else begin
      start_d <= start;
      state   <= next_state;

      case (state)
        IDLE: begin
          done   <= done; // hold until new start
          result <= result;
          if (start_pulse) begin
            // Initialize for new computation
            done   <= 1'b0;
            cur_n  <= n;
            // Clear bell and set bell[0][0] = 1
            for (r = 0; r < 8; r = r + 1) begin
              for (c = 0; c < 8; c = c + 1) begin
                bell[r][c] <= 32'd0;
              end
            end
            bell[0][0] <= 32'd1;
            i <= 4'd1;
            j <= 4'd0;
          end
        end

        INIT: begin
          // Initialization is effectively done in IDLE on start_pulse
          // Move to row computation
          i <= 4'd1;
          j <= 4'd0;
        end

        COMPUTE_ROW: begin
          // Set bell[i][0] <= bell[i-1][i-1]
          bell[i][0] <= bell[i-1][i-1];
          j <= 4'd1;
        end

        COMPUTE_COL: begin
          // Compute bell[i][j] <= bell[i-1][j-1] + bell[i][j-1]
          bell[i][j] <= bell[i-1][j-1] + bell[i][j-1];
          if (j < i) begin
            j <= j + 1'b1;
          end else begin
            // Finished row i
            if (i < cur_n) begin
              i <= i + 1'b1;
              j <= 4'd0;
            end else begin
              // All rows done
              // Prepare to go DONE_STATE in next_state logic
            end
          end
        end

        DONE_STATE: begin
          done   <= 1'b1;
          result <= bell[cur_n][0];
          // Hold done and result until next start
        end

        default: begin
          // Safety
          done <= 1'b0;
        end
      endcase
    end
  end

  // Next-state combinational logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_pulse) begin
          if (n == 4'd0) begin
            // B(0) = 1, directly go to DONE
            next_state = DONE_STATE;
          end else begin
            next_state = INIT;
          end
        end
      end

      INIT: begin
        // Go to compute first row
        next_state = COMPUTE_ROW;
      end

      COMPUTE_ROW: begin
        // After setting bell[i][0], compute columns for this row
        next_state = COMPUTE_COL;
      end

      COMPUTE_COL: begin
        if (j == i) begin
          // Completed all columns for this row
          if (i == cur_n) begin
            next_state = DONE_STATE;
          end else begin
            next_state = COMPUTE_ROW;
          end
        end else begin
          next_state = COMPUTE_COL;
        end
      end

      DONE_STATE: begin
        // Wait here until next start pulse
        if (start_pulse) begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule