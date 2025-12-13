module min_photo_area(
  input clk,
  input rst_n,
  input start,
  input [1:0] n,
  input [3:0] w0, w1, w2, w3,
  input [3:0] h0, h1, h2, h3,
  output reg [15:0] min_area,
  output reg done
);

  // State encoding
  localparam IDLE            = 3'd0;
  localparam INIT            = 3'd1;
  localparam LOOP_H          = 3'd2;
  localparam CHECK_MANDATORY = 3'd3;
  localparam CALC_OPTIONAL   = 3'd4;
  localparam SUM_WIDTH       = 3'd5;
  localparam UPDATE_MIN      = 3'd6;
  localparam DONE            = 3'd7;

  reg [2:0] state, next_state;

  // Registers for friend data
  reg [3:0] rw[3:0];
  reg [3:0] rh[3:0];

  // max_height loop variable (1..15)
  reg [3:0] max_h;

  // Loop indices
  reg [2:0] idx;          // up to 4
  reg [1:0] idx2;         // secondary small index

  // Parameters derived
  reg [2:0] n_ext;        // extended n (0..4)
  reg [2:0] floor_n2;     // floor(n/2)

  // Mandatory flip tracking
  reg [2:0] mand_flips;
  reg [2:0] possible_cnt;
  reg       reject_h;

  // Per-friend properties
  reg present[3:0];        // i < n
  reg mandatory[3:0];
  reg can_flip[3:0];       // optional flippable

  // Benefit (w - h) for optional
  reg [3:0] benefit[3:0];  // 0..15

  // Remaining flips allowed
  reg [2:0] remain_flips;

  // Selection for optional flips (greedy max benefit)
  reg       chosen[3:0];

  // Accumulation
  reg [6:0] total_width;   // up to 60

  // Product (7x4 -> 11 bits)
  wire [10:0] area_11;

  // 7x4 combinational multiplier
  assign area_11 = total_width * max_h;

  integer i;

  // Sequential state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      min_area  <= 16'hFFFF;
      done      <= 1'b0;
      max_h     <= 4'd0;
      idx       <= 3'd0;
      idx2      <= 2'd0;
      mand_flips <= 3'd0;
      possible_cnt <= 3'd0;
      reject_h  <= 1'b0;
      remain_flips <= 3'd0;
      total_width <= 7'd0;
      for (i = 0; i < 4; i = i + 1) begin
        rw[i] <= 4'd0;
        rh[i] <= 4'd0;
        present[i] <= 1'b0;
        mandatory[i] <= 1'b0;
        can_flip[i] <= 1'b0;
        benefit[i] <= 4'd0;
        chosen[i] <= 1'b0;
      end
      n_ext <= 3'd0;
      floor_n2 <= 3'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Latch inputs and initialize
            rw[0] <= w0; rw[1] <= w1; rw[2] <= w2; rw[3] <= w3;
            rh[0] <= h0; rh[1] <= h1; rh[2] <= h2; rh[3] <= h3;

            // Extend n and compute present flags next cycle in INIT
            min_area <= 16'hFFFF;
          end
        end

        INIT: begin
          // Setup n and presence
          n_ext <= {1'b0, n};

          present[0] <= (n != 2'd0);
          present[1] <= (n >  2'd1);
          present[2] <= (n >  2'd2);
          present[3] <= (n >  2'd3);

          // floor(n/2)
          case (n)
            2'd0: floor_n2 <= 3'd0;
            2'd1: floor_n2 <= 3'd0;
            2'd2: floor_n2 <= 3'd1;
            2'd3: floor_n2 <= 3'd1;
            default: floor_n2 <= 3'd2; // n==3 or n==4 -> 1 or 2, but for 4 will be overwritten by default
          endcase
          if (n == 2'd4) floor_n2 <= 3'd2;

          // Initialize loop over max_h
          max_h <= 4'd1;
        end

        LOOP_H: begin
          // Prepare for new max_h evaluation
          mand_flips   <= 3'd0;
          possible_cnt <= 3'd0;
          reject_h     <= 1'b0;
          remain_flips <= 3'd0;
          idx          <= 3'd0;

          for (i = 0; i < 4; i = i + 1) begin
            mandatory[i] <= 1'b0;
            can_flip[i]  <= 1'b0;
            benefit[i]   <= 4'd0;
            chosen[i]    <= 1'b0;
          end
        end

        CHECK_MANDATORY: begin
          // Process one friend per cycle to determine mandatory and optional
          if (idx < 4) begin
            if (present[idx]) begin
              // If height exceeds max_h, must flip
              if (rh[idx] > max_h) begin
                mandatory[idx] <= 1'b1;
                // If even flipped width (== h) still exceeds max_h, reject
                if (rw[idx] > max_h) begin
                  reject_h <= 1'b1;
                end
                mand_flips <= mand_flips + 3'd1;
              end else begin
                // Not mandatory; consider optional flippable
                if ((rh[idx] <= max_h) && (rw[idx] > rh[idx])) begin
                  can_flip[idx]  <= 1'b1;
                  benefit[idx]   <= rw[idx] - rh[idx];
                  possible_cnt   <= possible_cnt + 3'd1;
                end
              end
            end
            idx <= idx + 3'd1;
          end else begin
            // After scanning all, check constraints
            if (mand_flips > floor_n2) begin
              reject_h <= 1'b1;
            end
            if (!reject_h) begin
              remain_flips <= floor_n2 - mand_flips;
            end
          end
        end

        CALC_OPTIONAL: begin
          // Greedy selection of optional flips: choose max benefit while remain_flips > 0
          if (reject_h || (remain_flips == 0) || (possible_cnt == 0)) begin
            // Nothing to do or rejected
          end else begin
            // Find best candidate among can_flip & !chosen
            reg [1:0] best_idx;
            reg [3:0] best_benefit;
            reg       found;
            best_idx     = 2'd0;
            best_benefit = 4'd0;
            found        = 1'b0;

            for (i = 0; i < 4; i = i + 1) begin
              if (present[i] && can_flip[i] && !chosen[i]) begin
                if (!found || (benefit[i] > best_benefit)) begin
                  best_benefit = benefit[i];
                  best_idx     = i[1:0];
                  found        = 1'b1;
                end
              end
            end

            if (found && (remain_flips != 0)) begin
              chosen[best_idx] <= 1'b1;
              remain_flips     <= remain_flips - 3'd1;
              possible_cnt     <= possible_cnt - 3'd1;
            end else begin
              // No more beneficial choices
              remain_flips <= remain_flips; // hold
            end
          end
        end

        SUM_WIDTH: begin
          // Compute total_width = sum over friends of (flipped ? h : w)
          total_width <= 7'd0;
          for (i = 0; i < 4; i = i + 1) begin
            if (present[i]) begin
              if (mandatory[i] || chosen[i]) begin
                total_width <= total_width + rh[i];
              end else begin
                total_width <= total_width + rw[i];
              end
            end
          end
        end

        UPDATE_MIN: begin
          // Update min_area if not rejected and area smaller
          if (!reject_h) begin
            if ({5'd0, area_11} < min_area) begin
              min_area <= {5'd0, area_11};
            end
          end

          // Advance max_h
          if (max_h == 4'd15) begin
            // Completed all heights
          end else begin
            max_h <= max_h + 4'd1;
          end
        end

        DONE: begin
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT;
      end

      INIT: begin
        next_state = LOOP_H;
      end

      LOOP_H: begin
        next_state = CHECK_MANDATORY;
      end

      CHECK_MANDATORY: begin
        if (idx < 4) begin
          next_state = CHECK_MANDATORY;
        end else begin
          // All friends processed for this max_h
          next_state = CALC_OPTIONAL;
        end
      end

      CALC_OPTIONAL: begin
        if (reject_h) begin
          next_state = UPDATE_MIN; // will skip via reject flag
        end else if ((remain_flips == 0) || (possible_cnt == 0)) begin
          next_state = SUM_WIDTH;
        end else begin
          // Potentially select another optional flip in next cycle
          next_state = CALC_OPTIONAL;
        end
      end

      SUM_WIDTH: begin
        next_state = UPDATE_MIN;
      end

      UPDATE_MIN: begin
        if (max_h == 4'd15) begin
          next_state = DONE;
        end else begin
          next_state = LOOP_H;
        end
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end else begin
          next_state = DONE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule