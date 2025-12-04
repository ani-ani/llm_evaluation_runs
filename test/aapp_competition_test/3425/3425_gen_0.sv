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
  localparam IDLE       = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam FINISHED   = 2'b10;

  reg [1:0] state, next_state;

  // 16-bit configuration counter (0..65535)
  reg [15:0] cfg_counter;
  reg [15:0] cfg_mask;      // current configuration mask

  // Pipeline registers for 3-stage processing path
  // Stage 0: capture cfg_mask
  reg [15:0] p0_cfg_mask;
  // Stage 1: decode positions and basic counts
  reg [15:0] p1_cfg_mask;
  reg [3:0]  p1_qcount;
  reg        p1_usable;
  // Stage 2: final validity and max/ways update decision
  reg [3:0]  p2_qcount;
  reg        p2_valid;

  // Internal running best results (updated in PROCESSING)
  reg [3:0]  best_max_queens;
  reg [15:0] best_num_ways;

  // Signal to mark when we've fed the last configuration into pipeline
  wire last_cfg = (cfg_counter == 16'hFFFF);

  // ---------------------------------------------------------------------------
  // Next state logic
  // ---------------------------------------------------------------------------
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = PROCESSING;
      end
      PROCESSING: begin
        // Move to FINISHED after last configuration has passed through pipeline
        // We gate by a small completion counter below (implicit via done logic)
        if (done)
          next_state = FINISHED;
      end
      FINISHED: begin
        // Wait for start to deassert then assert again to restart
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // ---------------------------------------------------------------------------
  // Completion tracking: we must allow 2 extra cycles after last cfg fed
  // We'll use a small counter that starts when last_cfg is issued.
  // ---------------------------------------------------------------------------
  reg [1:0] tail_cnt;
  reg       tail_active;

  always @(posedge clk) begin
    if (!rst_n) begin
      state        <= IDLE;
      cfg_counter  <= 16'd0;
      cfg_mask     <= 16'd0;
      p0_cfg_mask  <= 16'd0;
      p1_cfg_mask  <= 16'd0;
      p1_qcount    <= 4'd0;
      p1_usable    <= 1'b0;
      p2_qcount    <= 4'd0;
      p2_valid     <= 1'b0;
      best_max_queens <= 4'd0;
      best_num_ways   <= 16'd0;
      done         <= 1'b0;
      max_queens   <= 4'd0;
      num_ways     <= 16'd0;
      tail_cnt     <= 2'd0;
      tail_active  <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done        <= 1'b0;
          tail_cnt    <= 2'd0;
          tail_active <= 1'b0;
          if (start) begin
            cfg_counter      <= 16'd0;
            cfg_mask         <= 16'd0;
            p0_cfg_mask      <= 16'd0;
            p1_cfg_mask      <= 16'd0;
            p1_qcount        <= 4'd0;
            p1_usable        <= 1'b0;
            p2_qcount        <= 4'd0;
            p2_valid         <= 1'b0;
            best_max_queens  <= 4'd0;
            best_num_ways    <= 16'd0;
          end
        end

        PROCESSING: begin
          // Feed configurations while not finished feeding
          if (!tail_active) begin
            cfg_mask <= cfg_counter;
            if (!last_cfg) begin
              cfg_counter <= cfg_counter + 16'd1;
            end else begin
              // After issuing last config, start tail phase next cycle
              tail_active <= 1'b1;
              tail_cnt    <= 2'd0;
            end
          end

          // -------------------- Pipeline Stage 0 -> Stage 1 -----------------
          p0_cfg_mask <= cfg_mask;

          // Stage 1: check usability and count queens
          begin : stage1
            integer i;
            reg [3:0] qcount;
            reg       usable;
            qcount = 4'd0;
            usable = 1'b1;
            for (i = 0; i < 16; i = i + 1) begin
              if (p0_cfg_mask[i]) begin
                if (!board_layout[i]) begin
                  usable = 1'b0;
                end
                qcount = qcount + 4'd1;
              end
            end
            p1_cfg_mask <= p0_cfg_mask;
            p1_qcount   <= qcount;
            p1_usable   <= usable;
          end

          // -------------------- Stage 2: validity & scoring ---------------
          begin : stage2
            // Decode all positions with queens into bitmasks for rows, cols, diags
            reg [3:0] rows;
            reg [3:0] cols;
            reg [7:0] diag_main;  // r-c from -3..3 mapped to 0..6 (index = (r-c)+3)
            reg [7:0] diag_anti;  // r+c from 0..6
            reg [3:0] pos_r [0:15];
            reg [3:0] pos_c [0:15];
            reg [3:0] idx_list [0:15];
            integer count;
            integer b;

            rows      = 4'b0;
            cols      = 4'b0;
            diag_main = 8'b0;
            diag_anti = 8'b0;
            count     = 0;

            // Collect queen positions
            for (b = 0; b < 16; b = b + 1) begin
              if (p1_cfg_mask[b]) begin
                pos_r[count]   = b[3:2];
                pos_c[count]   = b[1:0];
                idx_list[count]= b[3:0];
                // Mark attack lines
                rows[b[3:2]] = 1'b1;
                cols[b[1:0]] = 1'b1;
                diag_main[(b[3:2] - b[1:0]) + 3] = 1'b1;
                diag_anti[(b[3:2] + b[1:0])]      = 1'b1;
                count = count + 1;
              end
            end

            // Determine if any triplet of queens is collinear along row/col/diagonal
            // For grid size 4, any line with >=3 queens implies a bad triplet.
            reg invalid_triplet;
            integer x;
            invalid_triplet = 1'b0;

            // Check rows
            for (x = 0; x < 4; x = x + 1) begin
              if (!invalid_triplet) begin
                integer rc;
                rc = 0;
                for (b = 0; b < count; b = b + 1)
                  if (pos_r[b] == x[3:0]) rc = rc + 1;
                if (rc >= 3) invalid_triplet = 1'b1;
              end
            end

            // Check cols
            for (x = 0; x < 4; x = x + 1) begin
              if (!invalid_triplet) begin
                integer cc;
                cc = 0;
                for (b = 0; b < count; b = b + 1)
                  if (pos_c[b] == x[3:0]) cc = cc + 1;
                if (cc >= 3) invalid_triplet = 1'b1;
              end
            end

            // Check main diagonals
            for (x = 0; x <= 6; x = x + 1) begin
              if (!invalid_triplet) begin
                integer mc;
                mc = 0;
                for (b = 0; b < count; b = b + 1) begin
                  if ((pos_r[b] - pos_c[b] + 3) == x[3:0]) mc = mc + 1;
                end
                if (mc >= 3) invalid_triplet = 1'b1;
              end
            end

            // Check anti-diagonals
            for (x = 0; x <= 6; x = x + 1) begin
              if (!invalid_triplet) begin
                integer ac;
                ac = 0;
                for (b = 0; b < count; b = b + 1) begin
                  if ((pos_r[b] + pos_c[b]) == x[3:0]) ac = ac + 1;
                end
                if (ac >= 3) invalid_triplet = 1'b1;
              end
            end

            p2_qcount <= p1_qcount;
            p2_valid  <= (p1_usable && !invalid_triplet);
          end

          // -------------------- Update best_max_queens & best_num_ways ----
          if (p2_valid) begin
            if (p2_qcount > best_max_queens) begin
              best_max_queens <= p2_qcount;
              best_num_ways   <= 16'd1;
            end else if (p2_qcount == best_max_queens) begin
              best_num_ways   <= best_num_ways + 16'd1;
            end
          end

          // Tail handling: after last cfg is fed, wait 2 more cycles
          if (tail_active) begin
            if (tail_cnt < 2) begin
              tail_cnt <= tail_cnt + 2'd1;
            end else begin
              // After 2 extra cycles, we are done
              done         <= 1'b1;
              max_queens   <= best_max_queens;
              num_ways     <= best_num_ways;
            end
          end
        end

        FINISHED: begin
          // Hold results and done until restart
          done <= 1'b1;
          max_queens <= best_max_queens;
          num_ways   <= best_num_ways;
          // When we transition back to IDLE via next_state logic, INIT there
        end

        default: begin
          // Safety default
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule