module frog_jump(
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  input [3:0] K,
  input [127:0] plant_x,
  input [127:0] plant_y,
  input [31:0] directions,
  output reg [15:0] final_x,
  output reg [15:0] final_y,
  output reg done
);

  // Internal registers
  reg [15:0] plant_x_reg [0:7];
  reg [15:0] plant_y_reg [0:7];
  reg        valid_reg    [0:7];

  reg [15:0] cur_x;
  reg [15:0] cur_y;

  reg [3:0]  jump_cnt;       // counts processed jumps
  reg [3:0]  K_reg;          // latched K
  reg [3:0]  N_reg;          // latched N

  reg [31:0] directions_reg; // latched directions

  reg        busy;           // when processing active

  // State machine not strictly required; use busy + counters

  // Helper variables for combinational search
  reg [1:0]  dir_code;
  reg [15:0] best_dx;
  reg [15:0] best_dy;
  reg [2:0]  best_idx;
  reg        found;

  integer i;

  // Get current direction code from MSB-first packed directions.
  // directions_reg[31:30] is first jump, then [29:28], etc.
  wire [5:0] shift_amt = (K_reg - 1 - jump_cnt) << 1; // 2 * (K_reg-1-jump_cnt)
  wire [1:0] cur_dir = directions_reg[shift_amt +: 2];

  // Combinational block to select next plant based on direction
  always @* begin
    dir_code = cur_dir;
    best_dx  = 16'hFFFF; // maximal possible, we search for minimal positive
    best_dy  = 16'hFFFF;
    best_idx = 3'd0;
    found    = 1'b0;

    case (dir_code)
      2'b00: begin
        // Direction A: smallest positive delta X (to the right), same Y
        for (i = 0; i < 8; i = i + 1) begin
          if (valid_reg[i]) begin
            if (plant_y_reg[i] == cur_y && plant_x_reg[i] > cur_x) begin
              if (plant_x_reg[i] - cur_x < best_dx || !found || (plant_x_reg[i] - cur_x == best_dx && i < best_idx)) begin
                best_dx  = plant_x_reg[i] - cur_x;
                best_dy  = 16'd0;
                best_idx = i[2:0];
                found    = 1'b1;
              end
            end
          end
        end
      end

      2'b01: begin
        // Direction B: smallest positive delta Y (upwards), same X
        for (i = 0; i < 8; i = i + 1) begin
          if (valid_reg[i]) begin
            if (plant_x_reg[i] == cur_x && plant_y_reg[i] > cur_y) begin
              if (plant_y_reg[i] - cur_y < best_dy || !found || (plant_y_reg[i] - cur_y == best_dy && i < best_idx)) begin
                best_dy  = plant_y_reg[i] - cur_y;
                best_dx  = 16'd0;
                best_idx = i[2:0];
                found    = 1'b1;
              end
            end
          end
        end
      end

      2'b10: begin
        // Direction C: smallest positive delta X (to the left), same Y (assuming left: cur_x > plant_x)
        // Implement as positive (cur_x - plant_x)
        for (i = 0; i < 8; i = i + 1) begin
          if (valid_reg[i]) begin
            if (plant_y_reg[i] == cur_y && plant_x_reg[i] < cur_x) begin
              if (cur_x - plant_x_reg[i] < best_dx || !found || (cur_x - plant_x_reg[i] == best_dx && i < best_idx)) begin
                best_dx  = cur_x - plant_x_reg[i];
                best_dy  = 16'd0;
                best_idx = i[2:0];
                found    = 1'b1;
              end
            end
          end
        end
      end

      2'b11: begin
        // Direction D: smallest positive delta Y (downwards), same X (assuming down: cur_y > plant_y)
        // Implement as positive (cur_y - plant_y)
        for (i = 0; i < 8; i = i + 1) begin
          if (valid_reg[i]) begin
            if (plant_x_reg[i] == cur_x && plant_y_reg[i] < cur_y) begin
              if (cur_y - plant_y_reg[i] < best_dy || !found || (cur_y - plant_y_reg[i] == best_dy && i < best_idx)) begin
                best_dy  = cur_y - plant_y_reg[i];
                best_dx  = 16'd0;
                best_idx = i[2:0];
                found    = 1'b1;
              end
            end
          end
        end
      end

      default: begin
        // Should not occur
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous reset
      done       <= 1'b0;
      busy       <= 1'b0;
      jump_cnt   <= 4'd0;
      K_reg      <= 4'd0;
      N_reg      <= 4'd0;
      directions_reg <= 32'd0;
      cur_x      <= 16'd0;
      cur_y      <= 16'd0;
      final_x    <= 16'd0;
      final_y    <= 16'd0;
      for (i = 0; i < 8; i = i + 1) begin
        plant_x_reg[i] <= 16'd0;
        plant_y_reg[i] <= 16'd0;
        valid_reg[i]   <= 1'b0;
      end
    end else begin
      if (start && !busy) begin
        // Initialization (1 cycle)
        busy            <= 1'b1;
        done            <= 1'b0;
        K_reg           <= K;
        N_reg           <= N;
        directions_reg  <= directions;
        jump_cnt        <= 4'd0;

        // Unpack plants: plant 0 is bits [15:0], plant 1 [31:16], ...
        for (i = 0; i < 8; i = i + 1) begin
          plant_x_reg[i] <= plant_x[i*16 +: 16];
          plant_y_reg[i] <= plant_y[i*16 +: 16];
          if (i < N)
            valid_reg[i] <= 1'b1;
          else
            valid_reg[i] <= 1'b0;
        end

        // Start at plant 0
        cur_x <= plant_x[0 +: 16];
        cur_y <= plant_y[0 +: 16];
        // Invalidate plant 0 so it cannot be revisited
        valid_reg[0] <= (N > 0) ? 1'b0 : 1'b0;

      end else if (busy && !done) begin
        if (jump_cnt < K_reg) begin
          // One jump per cycle
          if (found) begin
            // Move to selected plant and invalidate it
            cur_x <= plant_x_reg[best_idx];
            cur_y <= plant_y_reg[best_idx];
            valid_reg[best_idx] <= 1'b0;
          end
          // If not found, stay in place (cur_x/cur_y unchanged)

          jump_cnt <= jump_cnt + 4'd1;

          // After processing K jumps, next cycle we output result
          if (jump_cnt == K_reg - 1) begin
            final_x <= found ? plant_x_reg[best_idx] : cur_x;
            final_y <= found ? plant_y_reg[best_idx] : cur_y;
            done    <= 1'b1;
            busy    <= 1'b0;
          end
        end
      end else begin
        // Idle waiting for next start
        done <= done; // hold
      end
    end
  end

endmodule