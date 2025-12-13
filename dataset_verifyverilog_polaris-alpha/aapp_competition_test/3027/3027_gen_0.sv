module stamp_nub_minimizer(
  input clk,
  input rst_n,
  input start,
  input [7:0] grid_height,
  input [7:0] grid_width,
  input [63:0] paper_mark,
  output reg [3:0] min_nubs,
  output reg done
);

  // State encoding
  localparam S_IDLE          = 3'd0;
  localparam S_INIT          = 3'd1;
  localparam S_NEW_SIZE      = 3'd2;
  localparam S_CHECK_PATTERN = 3'd3;
  localparam S_NEXT_PATTERN  = 3'd4;
  localparam S_NEXT_SIZE     = 3'd5;
  localparam S_DONE          = 3'd6;

  reg [2:0] state, next_state;

  // Internal registers
  reg [2:0] H, W;                // current stamp size (1-8)
  reg [2:0] h_idx, w_idx;        // iterators for size loops
  reg [6:0] pattern_idx;         // up to 2^(8*8) but practically up to 2^64; we limit by mask
  reg [63:0] pattern_mask;       // current pattern bits mapped into 8x8 frame
  reg [6:0] max_pattern_val;     // (1 << (H*W)) - 1, capped at 7 bits (valid since H*W<=8 for this encoding)
  reg [6:0] area;                // H*W

  reg [6:0] best_nubs;           // track minimum nubs, up to 64

  // Pre-processed paper info
  reg [63:0] paper_bits;         // relevant paper region (grid_height x grid_width) in 8x8 frame
  reg [6:0] needed_ones;         // popcount(paper_bits)

  // Flags and temporaries
  reg pattern_valid;             // pattern is able to cover paper with two placements
  reg [6:0] nubs_count;          // popcount(pattern_mask)

  // Placement iteration registers (sequentialized search)
  reg [2:0] x1, y1, x2, y2;      // positions for two placements
  reg [2:0] max_x, max_y;        // based on grid size and stamp size
  reg placing;                   // flag: currently scanning placements for this pattern

  // Combinational function: popcount 64-bit
  function automatic [6:0] popcount64(input [63:0] v);
    integer i;
    reg [6:0] cnt;
    begin
      cnt = 7'd0;
      for (i = 0; i < 64; i = i + 1) begin
        cnt = cnt + v[i];
      end
      popcount64 = cnt;
    end
  endfunction

  // Map pattern_idx (for HxW region) into 8x8-aligned pattern_mask (upper-left aligned)
  // Bits inside HxW are in row-major order from LSB of pattern_idx.
  function automatic [63:0] build_pattern_mask(
    input [6:0] pat_idx,
    input [2:0] H_f,
    input [2:0] W_f
  );
    integer r, c;
    integer bit_pos_src;
    integer bit_pos_dst;
    reg [63:0] m;
    begin
      m = 64'd0;
      bit_pos_src = 0;
      for (r = 0; r < 8; r = r + 1) begin
        for (c = 0; c < 8; c = c + 1) begin
          if ((r < H_f) && (c < W_f)) begin
            if (pat_idx[bit_pos_src]) begin
              bit_pos_dst = r*8 + c;
              m[bit_pos_dst] = 1'b1;
            end
            bit_pos_src = bit_pos_src + 1;
          end
        end
      end
      build_pattern_mask = m;
    end
  endfunction

  // Build paper_bits from paper_mark using grid_height and grid_width, upper-left aligned
  function automatic [63:0] build_paper_bits(
    input [63:0] in_bits,
    input [7:0] gh,
    input [7:0] gw
  );
    integer r, c;
    integer src_pos, dst_pos;
    reg [63:0] m;
    begin
      m = 64'd0;
      for (r = 0; r < 8; r = r + 1) begin
        for (c = 0; c < 8; c = c + 1) begin
          if ((r < gh) && (c < gw)) begin
            src_pos = r*8 + c;
            dst_pos = src_pos;
            m[dst_pos] = in_bits[src_pos];
          end
        end
      end
      build_paper_bits = m;
    end
  endfunction

  // Compute stamp placement mask for given top-left (x,y)
  function automatic [63:0] place_pattern(
    input [63:0] base_mask,
    input [2:0] x,
    input [2:0] y,
    input [2:0] H_f,
    input [2:0] W_f
  );
    integer r, c;
    integer src_pos, dst_pos;
    reg [63:0] m;
    begin
      m = 64'd0;
      for (r = 0; r < H_f; r = r + 1) begin
        for (c = 0; c < W_f; c = c + 1) begin
          src_pos = r*8 + c;
          if (base_mask[src_pos]) begin
            dst_pos = (y + r)*8 + (x + c);
            m[dst_pos] = 1'b1;
          end
        end
      end
      place_pattern = m;
    end
  endfunction

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end
      S_INIT: begin
        next_state = S_NEW_SIZE;
      end
      S_NEW_SIZE: begin
        // if all sizes tried, go DONE, else go to pattern loop
        if ((h_idx > grid_height[2:0]) || (h_idx == 3'd0) || (w_idx == 3'd0)) begin
          // safety; real control in sequential block
          next_state = S_NEW_SIZE;
        end else begin
          next_state = S_CHECK_PATTERN;
        end
      end
      S_CHECK_PATTERN: begin
        // stays until placement search done (controlled sequentially)
        if (pattern_valid || placing == 1'b0)
          next_state = S_NEXT_PATTERN;
        else
          next_state = S_CHECK_PATTERN;
      end
      S_NEXT_PATTERN: begin
        // decide to go next size or next pattern or done (sequential logic sets counters)
        next_state = S_NEW_SIZE;
      end
      S_NEXT_SIZE: begin
        next_state = S_NEW_SIZE;
      end
      S_DONE: begin
        if (!start)
          next_state = S_IDLE;
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      done        <= 1'b0;
      min_nubs    <= 4'd0;
      best_nubs   <= 7'd127; // large sentinel
      paper_bits  <= 64'd0;
      needed_ones <= 7'd0;
      h_idx       <= 3'd0;
      w_idx       <= 3'd0;
      H           <= 3'd0;
      W           <= 3'd0;
      pattern_idx <= 7'd0;
      pattern_mask<= 64'd0;
      max_pattern_val <= 7'd0;
      area        <= 7'd0;
      x1 <= 3'd0; y1 <= 3'd0; x2 <= 3'd0; y2 <= 3'd0;
      max_x <= 3'd0; max_y <= 3'd0;
      placing <= 1'b0;
      pattern_valid <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done        <= 1'b0;
          if (start) begin
            best_nubs   <= 7'd127;
            paper_bits  <= build_paper_bits(paper_mark, grid_height, grid_width);
            needed_ones <= popcount64(build_paper_bits(paper_mark, grid_height, grid_width));
            h_idx       <= 3'd1;
            w_idx       <= 3'd1;
          end
        end

        S_INIT: begin
          // already loaded; go to NEW_SIZE
        end

        S_NEW_SIZE: begin
          // Manage size loops and initialize first pattern for each size
          if (h_idx > grid_height[2:0]) begin
            // all sizes done
            if (best_nubs == 7'd127)
              min_nubs <= 4'd0;
            else
              min_nubs <= (best_nubs > 7'd15) ? 4'd15 : best_nubs[3:0];
            done      <= 1'b1;
            state     <= S_DONE;
          end else begin
            if (w_idx > grid_width[2:0]) begin
              // move to next height
              h_idx <= h_idx + 3'd1;
              w_idx <= 3'd1;
            end else begin
              // set current size
              H <= h_idx;
              W <= w_idx;
              area <= h_idx * w_idx;
              if (h_idx * w_idx == 0) begin
                // degenerate, skip
                w_idx <= w_idx + 3'd1;
              end else if (h_idx * w_idx > 7'd7) begin
                // Restriction for this implementation: only support up to 7 bits patterns
                // In this constrained implementation, skip too-large stamps
                w_idx <= w_idx + 3'd1;
              end else begin
                max_pattern_val <= (7'd1 << (h_idx * w_idx)) - 7'd1;
                pattern_idx     <= 7'd1; // start from 1: non-empty pattern
                placing         <= 1'b0;
                pattern_valid   <= 1'b0;
                // compute placement bounds
                max_x <= grid_width[2:0]  - w_idx;
                max_y <= grid_height[2:0] - h_idx;
                state <= S_CHECK_PATTERN;
              end
            end
          end
        end

        S_CHECK_PATTERN: begin
          if (!placing) begin
            if (pattern_idx == 7'd0 || pattern_idx > max_pattern_val) begin
              // no more patterns for this size
              w_idx  <= w_idx + 3'd1;
              state  <= S_NEW_SIZE;
            end else begin
              pattern_mask <= build_pattern_mask(pattern_idx, H, W);
              nubs_count   <= popcount64(build_pattern_mask(pattern_idx, H, W));

              // Early pruning: each placement uses same nubs_count; need union to cover needed_ones
              // Max cells covered by union of two placements is <= 2*nubs_count
              if ((2 * nubs_count) < needed_ones || nubs_count == 0) begin
                // impossible to cover; move to next pattern
                pattern_idx <= pattern_idx + 7'd1;
              end else begin
                // begin placement search
                x1 <= 3'd0; y1 <= 3'd0;
                x2 <= 3'd0; y2 <= 3'd0;
                placing <= 1'b1;
                pattern_valid <= 1'b0;
              end
            end
          end else begin
            // placement search running across cycles
            reg [63:0] p1, p2, uni;
            p1 = place_pattern(pattern_mask, x1, y1, H, W);
            p2 = place_pattern(pattern_mask, x2, y2, H, W);
            uni = p1 | p2;

            // Condition: union equals paper_bits within the grid; and no extra marks where paper has 0.
            if ((uni & paper_bits) == paper_bits && (uni & ~paper_bits) == 64'd0) begin
              pattern_valid <= 1'b1;
              placing       <= 1'b0;
              // record minimal nubs if better
              if (nubs_count < best_nubs)
                best_nubs <= nubs_count;
            end else begin
              // advance placement indices
              if (x2 < max_x) begin
                x2 <= x2 + 3'd1;
              end else begin
                x2 <= 3'd0;
                if (y2 < max_y) begin
                  y2 <= y2 + 3'd1;
                end else begin
                  y2 <= 3'd0;
                  if (x1 < max_x) begin
                    x1 <= x1 + 3'd1;
                  end else begin
                    x1 <= 3'd0;
                    if (y1 < max_y) begin
                      y1 <= y1 + 3'd1;
                    end else begin
                      // all pairs tested, no valid found
                      placing <= 1'b0;
                    end
                  end
                end
              end
            end

            if (!placing) begin
              state <= S_NEXT_PATTERN;
            end
          end
        end

        S_NEXT_PATTERN: begin
          // move to next pattern or next size
          if (pattern_idx >= max_pattern_val) begin
            // done all patterns for this size
            w_idx <= w_idx + 3'd1;
            state <= S_NEW_SIZE;
          end else begin
            pattern_idx <= pattern_idx + 7'd1;
            placing     <= 1'b0;
            pattern_valid <= 1'b0;
            state       <= S_CHECK_PATTERN;
          end
        end

        S_DONE: begin
          // hold done high until next start low then high
          if (!start) begin
            // ready for new run
          end
        end

        default: ;
      endcase
    end
  end

endmodule