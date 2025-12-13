module robot_position_checker(
  input clk,
  input rst_n,
  input start,
  input signed [15:0] a,
  input signed [15:0] b,
  input [15:0][1:0] cmd_string,
  output reg result,
  output reg done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE             = 2'b00,
    COMPUTE_STEPS    = 2'b01,
    CHECK_CONDITIONS = 2'b10,
    DONE_STATE       = 2'b11
  } state_t;

  state_t state, next_state;

  // Registers for command index and checking index
  reg [4:0] idx;          // used for step computation (0..15)
  reg [4:0] check_idx;    // used for checking (0..16 => up to 17 positions; use 5 bits)

  // Position step arrays for 16 commands
  reg signed [15:0] x_steps [0:15];
  reg signed [15:0] y_steps [0:15];

  // Total displacement after full command string
  reg signed [15:0] dx;
  reg signed [15:0] dy;

  // Internal flag
  reg found;

  // Sequential state and main control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      idx       <= 5'd0;
      check_idx <= 5'd0;
      dx        <= 16'sd0;
      dy        <= 16'sd0;
      result    <= 1'b0;
      done      <= 1'b0;
      found     <= 1'b0;
      // Clear step arrays
      x_steps[0]  <= 16'sd0; y_steps[0]  <= 16'sd0;
      x_steps[1]  <= 16'sd0; y_steps[1]  <= 16'sd0;
      x_steps[2]  <= 16'sd0; y_steps[2]  <= 16'sd0;
      x_steps[3]  <= 16'sd0; y_steps[3]  <= 16'sd0;
      x_steps[4]  <= 16'sd0; y_steps[4]  <= 16'sd0;
      x_steps[5]  <= 16'sd0; y_steps[5]  <= 16'sd0;
      x_steps[6]  <= 16'sd0; y_steps[6]  <= 16'sd0;
      x_steps[7]  <= 16'sd0; y_steps[7]  <= 16'sd0;
      x_steps[8]  <= 16'sd0; y_steps[8]  <= 16'sd0;
      x_steps[9]  <= 16'sd0; y_steps[9]  <= 16'sd0;
      x_steps[10] <= 16'sd0; y_steps[10] <= 16'sd0;
      x_steps[11] <= 16'sd0; y_steps[11] <= 16'sd0;
      x_steps[12] <= 16'sd0; y_steps[12] <= 16'sd0;
      x_steps[13] <= 16'sd0; y_steps[13] <= 16'sd0;
      x_steps[14] <= 16'sd0; y_steps[14] <= 16'sd0;
      x_steps[15] <= 16'sd0; y_steps[15] <= 16'sd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done   <= 1'b0;
          result <= 1'b0;
          found  <= 1'b0;
          if (start) begin
            // Initialize for computation
            idx       <= 5'd0;
            check_idx <= 5'd0;
            dx        <= 16'sd0;
            dy        <= 16'sd0;
            // Start from origin for first command
            x_steps[0] <= (cmd_string[0] == 2'b11) ? 16'sd1 :
                          (cmd_string[0] == 2'b10) ? -16'sd1 : 16'sd0;
            y_steps[0] <= (cmd_string[0] == 2'b00) ? 16'sd1 :
                          (cmd_string[0] == 2'b01) ? -16'sd1 : 16'sd0;
          end
        end

        COMPUTE_STEPS: begin
          // idx indicates the last computed index. When idx < 15, compute next.
          if (idx < 5'd15) begin
            // Compute next cumulative position based on previous
            // cmd_string index = idx+1
            // previous position = x_steps[idx], y_steps[idx]
            case (cmd_string[idx+1])
              2'b00: begin // U
                x_steps[idx+1] <= x_steps[idx];
                y_steps[idx+1] <= y_steps[idx] + 16'sd1;
              end
              2'b01: begin // D
                x_steps[idx+1] <= x_steps[idx];
                y_steps[idx+1] <= y_steps[idx] - 16'sd1;
              end
              2'b10: begin // L
                x_steps[idx+1] <= x_steps[idx] - 16'sd1;
                y_steps[idx+1] <= y_steps[idx];
              end
              2'b11: begin // R
                x_steps[idx+1] <= x_steps[idx] + 16'sd1;
                y_steps[idx+1] <= y_steps[idx];
              end
              default: begin
                x_steps[idx+1] <= x_steps[idx];
                y_steps[idx+1] <= y_steps[idx];
              end
            endcase
            idx <= idx + 5'd1;
          end else begin
            // When idx == 15, x_steps[15]/y_steps[15] already computed
            dx <= x_steps[15];
            dy <= y_steps[15];
          end
        end

        CHECK_CONDITIONS: begin
          // Perform one position check per cycle until finished or found
          if (!found) begin
            // Using combinational-like helper logic in sequential form
            // We'll compute conditions based on current check_idx
            // check_idx from 0..15 for x_steps/y_steps (interpreted as index i)
            // Additional i=16 representing end position (dx,dy) is implicitly handled
            reg signed [15:0] px;
            reg signed [15:0] py;
            reg signed [31:0] num_x;
            reg signed [31:0] num_y;
            reg signed [31:0] kx;
            reg signed [31:0] ky;
            reg               kx_ok;
            reg               ky_ok;
            reg               ok;

            px = x_steps[check_idx[3:0]];
            py = y_steps[check_idx[3:0]];

            // Default
            ok    = 1'b0;
            kx_ok = 1'b0;
            ky_ok = 1'b0;
            kx    = 32'sd0;
            ky    = 32'sd0;

            if ((dx == 16'sd0) && (dy == 16'sd0)) begin
              // No net movement: only reachable if (a,b) equals an intermediate position
              if ((a == px) && (b == py)) begin
                ok = 1'b1;
              end else begin
                ok = 1'b0;
              end
            end else if (dx == 16'sd0) begin
              // Vertical periodic movement
              if (a == px) begin
                if (dy != 16'sd0) begin
                  num_y = (b - py);
                  if (num_y >= 0 && (num_y % dy) == 0) begin
                    ky = num_y / dy;
                    if (ky >= 0)
                      ok = 1'b1;
                  end
                end else begin
                  ok = 1'b0;
                end
              end
            end else if (dy == 16'sd0) begin
              // Horizontal periodic movement
              if (b == py) begin
                if (dx != 16'sd0) begin
                  num_x = (a - px);
                  if (num_x >= 0 && (num_x % dx) == 0) begin
                    kx = num_x / dx;
                    if (kx >= 0)
                      ok = 1'b1;
                  end
                end else begin
                  ok = 1'b0;
                end
              end
            end else begin
              // Both dx and dy non-zero
              num_x = (a - px);
              num_y = (b - py);

              // Check divisibility and non-negative for x
              if ((dx != 0) && (num_x % dx) == 0) begin
                kx    = num_x / dx;
                kx_ok = (kx >= 0);
              end else begin
                kx_ok = 1'b0;
              end

              // Check divisibility and non-negative for y
              if ((dy != 0) && (num_y % dy) == 0) begin
                ky    = num_y / dy;
                ky_ok = (ky >= 0);
              end else begin
                ky_ok = 1'b0;
              end

              if (kx_ok && ky_ok && (kx == ky)) begin
                ok = 1'b1;
              end
            end

            if (ok) begin
              found <= 1'b1;
            end else begin
              // Move to next index if not found
              if (check_idx < 5'd15) begin
                check_idx <= check_idx + 5'd1;
              end else begin
                // After last index, no more checks
                check_idx <= check_idx;
              end
            end
          end
        end

        DONE_STATE: begin
          done   <= 1'b1;
          result <= found;
        end

        default: begin
          // Should not occur
          done   <= 1'b0;
          result <= 1'b0;
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = COMPUTE_STEPS;
      end

      COMPUTE_STEPS: begin
        // Wait until all steps computed and dx,dy captured
        if (idx == 5'd15) begin
          next_state = CHECK_CONDITIONS;
        end
      end

      CHECK_CONDITIONS: begin
        // Transition to DONE when found or after last check
        if (found) begin
          next_state = DONE_STATE;
        end else if (check_idx == 5'd15) begin
          next_state = DONE_STATE;
        end
      end

      DONE_STATE: begin
        // Return to IDLE when start is deasserted (simple handshake)
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule