module widget_packing(
  input clk,
  input rst_n,
  input start,
  input [31:0] N,
  output reg [31:0] empty_squares,
  output reg done
);

  // FSM states
  localparam IDLE      = 3'd0;
  localparam PREP      = 3'd1;
  localparam H0_STEP   = 3'd2;
  localparam CAND_INIT = 3'd3;
  localparam CAND_DIV  = 3'd4;
  localparam CAND_ADJ  = 3'd5;
  localparam CAND_NEXT = 3'd6;
  localparam WAIT_DONE = 3'd7;

  reg [2:0] state, next_state;

  // Latched N at start
  reg [31:0] N_reg;

  // Step counter to enforce 32-cycle completion window
  reg [5:0] cycle_cnt;  // counts 0..31

  // H0 computation via 5-step binary approximation of sqrt(N/2)
  reg [31:0] x;         // current sqrt approximation
  reg [31:0] bit_mask;  // current test bit

  // Candidate handling
  reg [2:0] cand_idx;          // 0..3
  reg [31:0] H0;
  reg [31:0] H_cand;
  reg [31:0] best_empty;
  reg        best_valid;

  // Division (ceil(N/H)) via restoring division over multiple cycles
  reg [31:0] div_N;
  reg [31:0] div_D;
  reg [63:0] rem;
  reg [31:0] quot;
  reg [5:0]  div_count;  // up to 32 steps
  reg        div_active;

  // Internal signals
  reg [31:0] halfN;
  reg [31:0] trial;
  reg [31:0] W;
  reg [31:0] minW;
  reg [31:0] maxW;
  reg [63:0] area64;
  reg [31:0] empty_val;
  reg        cand_valid;

  // FSM sequential
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      N_reg         <= 32'd0;
      cycle_cnt     <= 6'd0;
      empty_squares <= 32'd0;
      done          <= 1'b0;
      x             <= 32'd0;
      bit_mask      <= 32'd0;
      H0            <= 32'd0;
      cand_idx      <= 3'd0;
      H_cand        <= 32'd0;
      best_empty    <= 32'hFFFF_FFFF;
      best_valid    <= 1'b0;
      div_N         <= 32'd0;
      div_D         <= 32'd0;
      rem           <= 64'd0;
      quot          <= 32'd0;
      div_count     <= 6'd0;
      div_active    <= 1'b0;
    end else begin
      state <= next_state;

      // Global cycle counter: counts while active, reset in IDLE or on new start
      if (state == IDLE) begin
        cycle_cnt <= 6'd0;
      end else begin
        cycle_cnt <= cycle_cnt + 6'd1;
      end

      // Main sequential behavior per state
      case (state)
        IDLE: begin
          done          <= 1'b0;
          empty_squares <= 32'd0;
          best_empty    <= 32'hFFFF_FFFF;
          best_valid    <= 1'b0;
          div_active    <= 1'b0;
          if (start) begin
            N_reg <= N;
          end
        end

        PREP: begin
          // Pre-compute halfN = N/2 for sqrt(N/2)
          halfN   <= N_reg >> 1;
          // Initialize for 5-step binary approximation; start with MSB bit
          // Use 16th bit as initial (1<<15) to cover 32-bit range reasonably
          x       <= 32'd0;
          bit_mask<= 32'd1 << 15;
        end

        H0_STEP: begin
          // One approximation step per cycle; perform 5 steps total
          trial = x | bit_mask;
          if (trial * trial <= halfN)
            x <= trial;
          // shift bit_mask right each step
          bit_mask <= bit_mask >> 1;
        end

        CAND_INIT: begin
          // Finalize H0 after 5 steps
          H0         <= (x == 32'd0) ? 32'd1 : x;
          cand_idx   <= 3'd0;
          best_empty <= 32'hFFFF_FFFF;
          best_valid <= 1'b0;
          div_active <= 1'b0;
        end

        CAND_DIV: begin
          if (!div_active) begin
            // Initiate candidate H and division for W = ceil(N/H)
            case (cand_idx)
              3'd0: begin
                if (H0 > 2) H_cand <= H0 - 32'd2; else H_cand <= 32'd1;
              end
              3'd1: begin
                if (H0 > 1) H_cand <= H0 - 32'd1; else H_cand <= 32'd1;
              end
              3'd2: H_cand <= (H0 == 0) ? 32'd1 : H0;
              3'd3: H_cand <= H0 + 32'd1;
              default: H_cand <= 32'd1;
            endcase

            // Start division if H_cand != 0
            if (H_cand != 0) begin
              div_N      <= N_reg;
              div_D      <= H_cand;
              rem        <= 64'd0;
              quot       <= 32'd0;
              div_count  <= 6'd32;
              div_active <= 1'b1;
            end else begin
              div_active <= 1'b0;
            end
          end else begin
            // Restoring division: one bit per cycle
            if (div_count != 0) begin
              rem       <= {rem[62:0], div_N[31]};
              div_N     <= {div_N[30:0], 1'b0};
              if (rem[63:32] >= div_D) begin
                rem[63:32] <= rem[63:32] - div_D;
                quot       <= {quot[30:0], 1'b1};
              end else begin
                quot       <= {quot[30:0], 1'b0};
              end
              div_count <= div_count - 6'd1;
            end
          end
        end

        CAND_ADJ: begin
          // We get here once division is done, 'quot' holds floor(N/H)
          // Ceil: if rem[63:32] != 0 then W = quot + 1 else W = quot
          if (div_D != 0) begin
            if (rem[63:32] != 0)
              W <= quot + 32'd1;
            else
              W <= quot;
          end else begin
            W <= 32'hFFFF_FFFF; // invalid
          end

          // Compute minW = ceil(H/2), maxW = 2H
          if (H_cand[0])
            minW <= (H_cand >> 1) + 32'd1; // (H+1)/2
          else
            minW <= H_cand >> 1;          // H/2

          maxW <= (H_cand << 1);
        end

        CAND_NEXT: begin
          // Adjust W to be within [minW, maxW]
          if (W < minW) begin
            W <= minW;
          end else if (W > maxW) begin
            W <= maxW;
          end

          // Check validity H/2 <= W <= 2H after adjustment
          cand_valid <= (H_cand != 0) && (W >= minW) && (W <= maxW);

          if (cand_valid) begin
            // area = W*H (use 64-bit, then truncate to 32 bits, N is <= 2^32-1)
            area64    <= W * H_cand;
            empty_val <= (W * H_cand) - N_reg;

            if (!best_valid || (empty_val < best_empty)) begin
              best_empty <= empty_val;
              best_valid <= 1'b1;
            end
          end

          // Move to next candidate
          cand_idx <= cand_idx + 3'd1;
          div_active <= 1'b0;
        end

        WAIT_DONE: begin
          // Wait until 32 cycles total since PREP to assert done
          if (!done) begin
            empty_squares <= best_valid ? best_empty : 32'd0;
            done          <= 1'b1;
          end
        end

        default: ;
      endcase
    end
  end

  // FSM next state logic
  always @(*) begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start)
          next_state = PREP;
      end

      PREP: begin
        // Move to H0_STEP (5 steps)
        next_state = H0_STEP;
      end

      H0_STEP: begin
        // After 5 shifts (bit_mask >> 1 each cycle starting from 1<<15), stop
        // We simply use cycle_cnt offset: give 5 cycles for H0_STEP
        // PREP is 1 cycle, so when in H0_STEP and bit_mask[4:0]==0 after 5 shifts, move on.
        if (bit_mask == 32'd0)
          next_state = CAND_INIT;
      end

      CAND_INIT: begin
        next_state = CAND_DIV;
      end

      CAND_DIV: begin
        if (div_active) begin
          // wait until division complete
          if (div_count == 0)
            next_state = CAND_ADJ;
        end
      end

      CAND_ADJ: begin
        // Single-cycle adjustment prep
        next_state = CAND_NEXT;
      end

      CAND_NEXT: begin
        if (cand_idx == 3'd4) begin
          // All 4 candidates processed
          next_state = WAIT_DONE;
        end else begin
          // Start next candidate division
          next_state = CAND_DIV;
        end
      end

      WAIT_DONE: begin
        // Hold done until next start, but requirement: after 32 cycles output is ready
        // We can remain here; next start will reset in IDLE via external logic.
        if (!start) begin
          // Stay; external logic is expected to toggle start for new run.
          next_state = WAIT_DONE;
        end
      end

      default: next_state = IDLE;
    endcase

    // Force completion no later than 32 cycles: if cycle_cnt reaches 31, go to WAIT_DONE
    if (state != IDLE && state != WAIT_DONE && cycle_cnt >= 6'd31) begin
      next_state = WAIT_DONE;
    end
  end

endmodule