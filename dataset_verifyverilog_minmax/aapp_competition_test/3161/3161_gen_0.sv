module josip_painter(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start processing
  input [63:0] target_image, // flattened 8x8 image (MSB-first row-wise)
  output reg [6:0] min_difference, // maximum possible is 64 (7 bits)
  output reg [63:0] output_image, // resulting paintable image
  output reg done // high when computation complete
);

  // Types and parameters
  typedef enum logic [3:0] {
    S_IDLE      = 4'd0,
    S_START     = 4'd1,
    S_LEVEL_INIT= 4'd2,
    S_LEVEL_LOOP= 4'd3,
    S_POP_STACK = 4'd4,
    S_DONE      = 4'd5
  } state_t;

  state_t state, next_state;

  // Level tracking: k in {3,2,1,0} for 8->4->2->1
  logic [2:0] level;          // 0..3 (we store k directly)
  logic [2:0] level_next;
  logic [3:0] logN;           // log2(N) (3 for 8x8)
  logic [1:0] lgsize;         // 2^k size in pixels (1,2,4,8)
  logic [5:0] pixels_per_node; // 2^(2*k)
  logic [5:0] nodes_at_level; // 4^(3-k)
  logic [5:0] nodes_processed; // modulo nodes_at_level

  // Current node context
  logic [5:0] bit_index;      // bit position within 64-bit for current node
  logic [63:0] s_mask;        // mask of pixels belonging to the current node (valid=1)
  logic [5:0] ones_in_s;      // count of '1' in target_image & s_mask
  logic [5:0] valids_in_s;    // number of valid pixels in this node (should be 2^(2*k))
  logic [5:0] diff0, diff1;   // differences for white(0) and black(1) selection
  logic split_this_node;      // whether this node is split (diff0<diff1)

  // Split stack: push parent nodes that we need to revisit after children are done
  // Depth is at most (1 + 4 + 16) = 21
  logic [4:0] stack_top;      // points to next free slot
  logic [7:0] stack_k   [0:20]; // k for node at stack entry (0..3)
  logic [7:0] stack_k4  [0:20]; // k*4 + position (0..63)
  logic [3:0] stack_cnt [0:20]; // how many children of this parent remain to be processed
  logic       stack_push;
  logic       stack_pop;

  // Mask for the next level (2^(k-1) regions)
  logic [63:0] s_mask_next;
  logic [1:0] quadrant_pos; // 0..3 for TL,TR,BL,BR
  logic [5:0] next_mask_bit_index;
  logic [63:0] mask_bit_value; // 1 << next_mask_bit_index
  logic       do_pop;

  // Temporary signals
  logic [5:0] ones_in_child;
  logic [6:0] total_diff;
  logic [6:0] total_diff_next;

  // Choose quadrant masks (TL,TR,BL,BR) for a 2^(k) x 2^(k) node, k>=1
  function [63:0] quadrant_mask;
    input [2:0] k;        // node level (3..1)
    input [1:0] pos;      // quadrant position 0:TL, 1:TR, 2:BL, 3:BR
    input [5:0] base_bit; // bit index of top-left pixel of this node
    reg [5:0] half;
    reg [5:0] hdim;
    reg [5:0] col_start, row_start;
    reg [63:0] m;
    integer r,c;
    begin
      half  = 1 << (k-1);    // 2^(k-1)
      hdim  = half * 8;      // number of bits in half rows in the flattened image
      case (pos)
        2'd0: begin col_start = 0;           row_start = 0;           end // TL
        2'd1: begin col_start = half;        row_start = 0;           end // TR
        2'd2: begin col_start = 0;           row_start = half;        end // BL
        2'd3: begin col_start = half;        row_start = half;        end // BR
      endcase
      m = 64'b0;
      for (r=0; r<half; r=r+1) begin
        for (c=0; c<half; c=c+1) begin
          m[base_bit + r*8 + c + row_start*8 + col_start] = 1'b1;
        end
      end
      quadrant_mask = m;
    end
  endfunction

  // Count '1's in a 64-bit vector
  function [6:0] popcount64;
    input [63:0] vec;
    integer i;
    reg [6:0] cnt;
    begin
      cnt = 0;
      for (i=0;i<64;i=i+1) begin
        if (vec[i]) cnt = cnt + 1;
      end
      popcount64 = cnt;
    end
  endfunction

  // Bit position encoder for 0..15 -> 0..63
  function [5:0] bitpos_from_k4;
    input [7:0] k4; // k*4 + position (0..63)
    input [2:0] k;  // current level k
    reg [1:0] pos;
    reg [1:0] half_cols;
    reg [5:0] base_bit;
    begin
      pos = k4[1:0];            // 0..3
      base_bit = (k4 >> 2) * 4; // 4,8,12,... or 0 for k=0
      half_cols = (k>=1) ? (1 << (k-1)) : 2'd1;
      case (pos)
        2'd0: bitpos_from_k4 = base_bit;                         // TL
        2'd1: bitpos_from_k4 = base_bit + half_cols;              // TR
        2'd2: bitpos_from_k4 = base_bit + (half_cols * 8);        // BL
        2'd3: bitpos_from_k4 = base_bit + (half_cols * 8) + half_cols; // BR
      endcase
    end
  endfunction

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      level      <= 3'd0;
      output_image <= 64'b0;
      min_difference <= 7'd0;
      done       <= 1'b0;
      nodes_processed <= 6'd0;
      stack_top  <= 5'd0;
      s_mask     <= 64'b0;
      bit_index  <= 6'd0;
      split_this_node <= 1'b0;
    end else begin
      // Defaults
      done <= 1'b0;
      stack_push <= 1'b0;
      stack_pop  <= 1'b0;
      next_state <= state;

      case (state)
        S_IDLE: begin
          if (start) next_state <= S_START;
        end

        S_START: begin
          output_image   <= 64'b0;
          min_difference <= 7'b0;
          total_diff     <= 7'b0;
          stack_top      <= 5'd0;
          // Always process as 8x8; bits outside NxN are simply unused (differences 0)
          logN      <= 3'd3;            // log2(8) = 3
          lgsize    <= 3'd3;            // current k (3 down to 0)
          level     <= 3'd3;            // k = 3
          next_state <= S_LEVEL_INIT;
          s_mask    <= 64'hFFFF_FFFF_FFFF_FFFF; // all 64 bits valid at top level
        end

        S_LEVEL_INIT: begin
          // Set parameters for this level
          lgsize <= level;                           // k
          pixels_per_node <= (1 << (2*level));       // 2^(2k)
          nodes_at_level  <= (1 << (2*(3-level)));  // 4^(3-k)
          nodes_processed <= 6'd0;
          next_state <= S_LEVEL_LOOP;
        end

        S_LEVEL_LOOP: begin
          if (nodes_processed == nodes_at_level) begin
            // Done with this level
            if (level == 3'd0) begin
              // All leaves processed: final total diff already accumulated
              next_state <= S_DONE;
            end else if (stack_top == 5'd0) begin
              // No parents to pop: finishing early with total_diff as is
              next_state <= S_DONE;
            end else begin
              next_state <= S_POP_STACK;
            end
          end else begin
            // Process one node at this level
            bit_index     <= nodes_processed * pixels_per_node;
            s_mask        <= (pixels_per_node == 1) ? (64'b1 << (nodes_processed)) : 64'b0; // will be replaced below when k>0
            split_this_node <= 1'b0;

            if (lgsize == 3'd0) begin
              // Leaf: 1x1 region
              ones_in_s     <= (target_image >> nodes_processed) & 64'b1;
              valids_in_s   <= 6'd1;
              diff0         <= 6'd0; // white: mismatch if bit is 1
              diff1         <= 6'd1; // black: mismatch if bit is 0
              split_this_node <= 1'b0;
              // Use target pixel for this pixel
              if (ones_in_s[0]) output_image <= output_image | (64'b1 << nodes_processed);
              else              output_image <= output_image & ~(64'b1 << nodes_processed);
              total_diff <= total_diff + ((ones_in_s[0]) ? 7'd1 : 7'd0);
              nodes_processed <= nodes_processed + 1;
              // If leaf at top level only, then next_state is handled when nodes_processed wraps
            end else begin
              // Non-leaf: build mask for the 2^k x 2^k region and count ones/valids
              s_mask <= (level == 3'd3) ? 64'hFFFF_FFFF_FFFF_FFFF : s_mask; // for k=3, mask is all 1s
              if (level != 3'd3) begin
                // Build mask for this node for k<3
                s_mask <= quadrant_mask(level, 2'd0, (nodes_processed * pixels_per_node)) |
                          quadrant_mask(level, 2'd1, (nodes_processed * pixels_per_node)) |
                          quadrant_mask(level, 2'd2, (nodes_processed * pixels_processed)) |
                          quadrant_mask(level, 2'd3, (nodes_processed * pixels_per_node));
              end
            end

            // On next cycle we use s_mask to compute counts and decide splitting
            // But we need to wait one extra cycle after s_mask was assigned.
            // Hence, split decision and effects handled in the same cycle when we are in S_LEVEL_LOOP
            // and nodes_processed was already used to derive s_mask for this node.
            // To support this, we make split decision in the same cycle where s_mask is ready.

            // The above combinational assignment to s_mask has a race; to be safe, compute counts here:
            ones_in_s   <= popcount64(target_image & s_mask);
            valids_in_s <= popcount64(s_mask);
            diff0       <= valids_in_s - ones_in_s; // white(0) mismatches = number of 1s
            diff1       <= ones_in_s;               // black(1) mismatches = number of 1s
            if ((valids_in_s - ones_in_s) < ones_in_s) begin
              split_this_node <= 1'b0; // choose white
              // Paint this node white: ensure 0s in s_mask
              output_image <= output_image & ~s_mask;
            end else begin
              split_this_node <= 1'b1; // choose black
              // Paint this node black: set 1s in s_mask
              output_image <= output_image | s_mask;
            end
            // Accumulate difference for this node using the chosen color
            total_diff <= total_diff + ((diff0 < diff1) ? diff0 : diff1);
            nodes_processed <= nodes_processed + 1;

            // If we are at the last node of this level, next_state will be updated in the following cycle via S_LEVEL_INIT or S_POP_STACK.
          end
        end

        S_POP_STACK: begin
          // We are here only if we finished a level early (all white at a higher level) and need to pop a parent to process its other child
          if (stack_top == 5'd0) begin
            // Nothing left: we're done
            next_state <= S_DONE;
          end else begin
            stack_top <= stack_top - 1;
            // For the popped parent we need to decrement its remaining child count and proceed to its child
            if (stack_cnt[stack_top-1] == 4'd1) begin
              // This is the last child of its parent: pop again next time
              stack_pop <= 1'b1;
            end
            // Descend to the child: set up masks and counters for parent's level (k)
            level     <= stack_k[stack_top-1];
            // We are processing a child of that parent; nodes_at_level is recomputed when we go to S_LEVEL_INIT next cycle
            next_state <= S_LEVEL_INIT;
          end
        end

        S_DONE: begin
          min_difference <= total_diff[6:0];
          done <= 1'b1;
          next_state <= S_IDLE;
        end

        default: next_state <= S_IDLE;
      endcase

      // Handle stack push when a node is split
      // Note: This block runs every cycle; we push when we just processed a node that split and we are at non-leaf level.
      // We need to detect we are in S_LEVEL_LOOP and just processed a node that split.
      // Because we updated split_this_node within S_LEVEL_LOOP and it was derived combinatorially,
      // we need an auxiliary flag to indicate the push should occur.
      // For simplicity, we infer it by checking state and if the node was split.
      // To avoid long combinational paths, we introduce a one-cycle delay on push detection.

      // Update registers derived from S_LEVEL_LOOP
      state <= next_state;
    end
  end

  // Push management and child descent:
  // When a node is split (k>0), push parent onto stack with remaining children = 3 (other 3 quadrants),
  // then descend to its first child (position 0).
  // The actual descent is modeled by reusing the same level (k) and adjusting processing to that child's region.
  // For descent, we also set s_mask to the child's quadrant mask for the next cycle.
  // The following combinational logic drives s_mask_next, next_mask_bit_index and stack control.

  // Additional state to remember we just split a node in the previous cycle
  logic split_latched;
  logic [2:0] split_k_latched;
  logic [7:0] split_k4_latched;

  always @(posedge clk) begin
    if (!rst_n) begin
      split_latched    <= 1'b0;
      split_k_latched  <= 3'd0;
      split_k4_latched <= 8'd0;
    end else begin
      // Latch split decision in S_LEVEL_LOOP before it transitions
      if (state == S_LEVEL_LOOP) begin
        if (level != 3'd0) begin
          split_latched   <= split_this_node;
          split_k_latched <= level;
          split_k4_latched <= (level<<2) + nodes_processed; // parent k*4 + position
        end else begin
          split_latched   <= 1'b0;
        end
      end else begin
        split_latched   <= 1'b0;
      end
    end
  end

  // Drive s_mask for the next cycle when descending (applies when a split was decided last cycle)
  always_comb begin
    s_mask_next = 64'b0;
    next_mask_bit_index = 6'd0;
    mask_bit_value = 64'b1;
    do_pop = 1'b0;
    total_diff_next = total_diff;

    if (rst_n && (state == S_LEVEL_LOOP)) begin
      if (split_latched) begin
        // We are descending to child position 0 of the parent node that just split
        // Determine child's k = parent_k - 1
        // Child base index is: k4_parent*4 + 0
        next_mask_bit_index = bitpos_from_k4((split_k4_latched<<2), (split_k_latched - 1));
        mask_bit_value = (1 << next_mask_bit_index);
        s_mask_next = mask_bit_value; // For k-1, the quadrant mask for a single pixel is just 1 bit at that index
        // Push the parent to stack with remaining children = 3 (positions 1,2,3)
        // We cannot write to stack arrays here; this is handled below in an always_ff.
        // Provide values for stack control below.
      end
    end else if ((state == S_POP_STACK) && (stack_top > 0)) begin
      // When popping, we are processing the next child of stack_top-1
      // Determine which child index remains: children_left = stack_cnt[stack_top-1]
      // Children order: when we pushed, we decremented from 3 to 2 after first child, so
      // remaining children are 3,2,1... We process positions 1,2,3 in order.
      // The child position to process is: 4 - stack_cnt[stack_top-1]
      // For example: remaining 3 -> pos 1; remaining 2 -> pos 2; remaining 1 -> pos 3
      // k for the parent is stack_k[stack_top-1]; child k = parent_k - 1
      // base k4_parent = stack_k4[stack_top-1]
      // child k4 = k4_parent*4 + child_pos
      // then child mask bit index = bitpos_from_k4(child_k4, child_k-1)
      // We'll compute this in the always_ff below; here just indicate pop
      do_pop = 1'b1;
    end
  end

  // Stack control and automatic descent
  always @(posedge clk) begin
    if (!rst_n) begin
      // already reset stack_top in main reset
    end else begin
      // Handle push when a node split in the previous cycle
      if (state == S_LEVEL_LOOP) begin
        if (split_latched && (split_k_latched > 0)) begin
          // Push current parent onto stack (one level up only when we just started processing its children)
          // If this is the first child, push; else it's already on the stack
          // To detect first child, we check that this node is exactly the one whose parent wasn't pushed yet.
          // For simplicity, push unconditionally; stack depth max 21; push only once per parent.
          // We track this by remembering that we push when we transition to processing the first child.
          // We'll push when we are starting the first child after a split.
          // In S_LEVEL_LOOP cycle when split_latched is set, we are still at parent level; next cycle we go to S_LEVEL_INIT with same k
          // and will start child 0. We'll push now to mark parent has children pending (3 remaining after this one).
          if (stack_top < 5'd21) begin
            stack_k[stack_top]  <= split_k_latched;
            stack_k4[stack_top] <= split_k4_latched;
            stack_cnt[stack_top]<= 4'd3; // positions 1,2,3 remain after this one
            stack_top <= stack_top + 1;
          end
        end
      end else if (state == S_POP_STACK) begin
        // When popping, we process the next child of the parent at stack_top-1
        if (stack_top > 0) begin
          // Decrement the remaining children for this parent
          if (stack_cnt[stack_top-1] > 0) begin
            stack_cnt[stack_top-1] <= stack_cnt[stack_top-1] - 1;
          end
          // If this was the last child, we will pop again next cycle (handled in S_POP_STACK logic)
        end
      end
    end
  end

  // Apply s_mask for child descent when split_latched is true
  always @(posedge clk) begin
    if (!rst_n) begin
      // no action
    end else begin
      if (state == S_LEVEL_LOOP) begin
        if (split_latched && (split_k_latched > 0)) begin
          s_mask <= s_mask_next; // set mask to the first child's region
        end
      end
    end
  end

  // Update level when descending or ascending
  always @(posedge clk) begin
    if (!rst_n) begin
      level <= 3'd0;
    end else begin
      case (state)
        S_START:   level <= 3'd3;
        S_LEVEL_INIT: begin
          // Determine if we are descending due to a split_latched last cycle
          if (split_latched && (split_k_latched > 0)) begin
            level <= split_k_latched - 1; // descending to first child
          end else if ((state == S_POP_STACK) && (stack_top > 0)) begin
            // When popping, we go to child of the popped parent at (parent_k - 1)
            level <= stack_k[stack_top-1] - 1;
          end else if ((next_state == S_LEVEL_INIT) && (level > 0) && (nodes_processed == nodes_at_level) && (stack_top == 5'd0)) begin
            // Finished current level with all children white -> climb up (no stack entries)
            level <= level - 1;
          end
        end
        S_POP_STACK: begin
          // After popping, we will initialize for that child's level in the next cycle (S_LEVEL_INIT)
        end
        default: ;
      endcase
    end
  end

  // Increment/decrement min_difference using total_diff at the end
  always @(posedge clk) begin
    if (!rst_n) begin
      min_difference <= 7'd0;
    end else if (state == S_DONE) begin
      min_difference <= total_diff[6:0];
    end
  end

endmodule