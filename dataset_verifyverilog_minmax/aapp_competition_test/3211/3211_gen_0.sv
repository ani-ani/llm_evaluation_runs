module vote_swap_optimizer (
  input clk,
  input rst_n,
  input start,
  input [31:0] input_str,
  output reg [4:0] min_swaps,
  output reg is_impossible,
  output reg done
);

  // Constants
  localparam NUM_POS = 16;
  localparam MAX_SWAP = 15;  // Maximum adjacent swaps to exhaust (0..15)
  localparam IDLE       = 3'b000;
  localparam INIT       = 3'b001;
  localparam COUNT_VOTES= 3'b010;
  localparam CHECK_WIN  = 3'b011;
  localparam MOVE_TELLERS=3'b100;
  localparam DONE       = 3'b101;

  // 8-bit counters for votes
  reg [7:0] p1_votes, p2_votes;
  // 4-bit point counters
  reg [3:0] p1_adj_points, p2_adj_points;
  // 5-bit index for positions (0..15)
  reg [4:0] count_idx;
  // 5-bit target swaps (0..15)
  reg [4:0] target_swaps;
  // 4-bit swap counter (0..15)
  reg [3:0] swaps_done;
  // Current per-position code (2 bits): 0=teller,1=party1,2=party2
  reg [1:0] cur_pos_code;
  // Working copy of the input string (16x2 bits)
  reg [31:0] work_str;

  // State machine
  reg [2:0] state, next_state;
  
  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      is_impossible <= 1'b0;
      min_swaps <= 5'b0;
    end else begin
      state <= next_state;
      
      // default: hold outputs; updated in the state logic when needed
      done <= done;
      is_impossible <= is_impossible;
      min_swaps <= min_swaps;
    end
  end

  // Combinational next-state and datapath update
  always @(*) begin
    // Defaults
    next_state = state;
    done = 1'b0;
    
    case (state)
      IDLE: begin
        // Reset datapath-ish in IDLE for stable reset response
        p1_votes = 8'b0;
        p2_votes = 8'b0;
        p1_adj_points = 4'b0;
        p2_adj_points = 4'b0;
        count_idx = 5'b0;
        target_swaps = 5'b0;
        swaps_done = 4'b0;
        cur_pos_code = 2'b0;
        work_str = 32'b0;
        min_swaps = 5'b0;
        is_impossible = 1'b0;
        
        if (start) begin
          work_str = input_str;   // capture snapshot
          next_state = INIT;
        end else begin
          next_state = IDLE;
        end
      end

      INIT: begin
        // Initialize everything for a fresh run
        p1_votes = 8'b0;
        p2_votes = 8'b0;
        p1_adj_points = 4'b0;
        p2_adj_points = 4'b0;
        count_idx = 5'b0;
        target_swaps = 5'b0;  // start trying 0 swaps first
        swaps_done = 4'b0;
        next_state = COUNT_VOTES;
      end

      COUNT_VOTES: begin
        // Scan 16 positions and compute votes and adjacent teller points for both parties.
        // Adjacent teller points: any teller adjacent to a party contributes 1 point to that party.
        // Teller-to-teller adjacency yields no points.
        cur_pos_code = work_str[(count_idx*2) +: 2];
        if (cur_pos_code == 2'b01) begin
          p1_votes = p1_votes + 1;
        end else if (cur_pos_code == 2'b10) begin
          p2_votes = p2_votes + 1;
        end
        // Teller adjacency points: only count when current is a party code
        if (cur_pos_code == 2'b01) begin
          if (count_idx > 0) begin
            if (work_str[((count_idx-1)*2) +: 2] == 2'b00) p1_adj_points = p1_adj_points + 1;
          end
          if (count_idx < (NUM_POS-1)) begin
            if (work_str[((count_idx+1)*2) +: 2] == 2'b00) p1_adj_points = p1_adj_points + 1;
          end
        end else if (cur_pos_code == 2'b10) begin
          if (count_idx > 0) begin
            if (work_str[((count_idx-1)*2) +: 2] == 2'b00) p2_adj_points = p2_adj_points + 1;
          end
          if (count_idx < (NUM_POS-1)) begin
            if (work_str[((count_idx+1)*2) +: 2] == 2'b00) p2_adj_points = p2_adj_points + 1;
          end
        end
        
        if (count_idx == (NUM_POS-1)) begin
          next_state = CHECK_WIN;
        end else begin
          count_idx = count_idx + 1;
          next_state = COUNT_VOTES;
        end
      end

      CHECK_WIN: begin
        // Determine if party 1 wins (votes + adjacent teller points > party 2's)
        if ((p1_votes + p1_adj_points) > (p2_votes + p2_adj_points)) begin
          // Success: record min swaps and finish
          min_swaps = {1'b0, target_swaps[3:0]};  // ensure 5-bit width
          is_impossible = 1'b0;
          done = 1'b1;
          next_state = DONE;
        end else begin
          // Not a win at this swap count; try next or fail if exhausted
          if (target_swaps < MAX_SWAP) begin
            next_state = MOVE_TELLERS;
          end else begin
            // Exhausted all swap budgets: impossible
            is_impossible = 1'b1;
            done = 1'b1;
            next_state = DONE;
          end
        end
      end

      MOVE_TELLERS: begin
        // Increment the swaps budget and construct a new sequence by moving the rightmost
        // teller right by one position (adjacent swap). If the teller is already at the far right,
        // wrap and move the next-rightmost teller, etc. This enumerates configurations reachable
        // with up to target_swaps adjacent swaps on the rightmost tellers first.
        swaps_done = swaps_done + 1;
        
        // Compute target index (starting from the far right teller, then second-rightmost, etc.)
        // i_target = NUM_POS-1 - (swaps_done-1)
        // 0 swaps -> i_target = 15; 1 swap -> i_target = 14; ...
        // Only proceed if i_target >= 0
        if (swaps_done <= NUM_POS) begin
          // Perform adjacent swap of teller at i_target with its right neighbor, if any
          // Build swap bitmask: swap (i_target, i_target+1) if i_target < 15
          // Reconstruct work_str accordingly
          work_str = work_str; // hold value for readability
          
          if (swaps_done > 0) begin
            integer i_tgt;
            i_tgt = (NUM_POS - 1) - (swaps_done - 1);
            if (i_tgt >= 0 && i_tgt < (NUM_POS - 1)) begin
              integer j;
              reg [1:0] a, b;
              j = i_tgt + 1;
              a = work_str[(i_tgt*2) +: 2];
              b = work_str[(j*2) +: 2];
              // swap adjacent only if a is a teller (00) and b is not (non-00)
              if (a == 2'b00 && b != 2'b00) begin
                work_str[(i_tgt*2) +: 2] = b;
                work_str[(j*2) +: 2] = a;
              end
              // else: no change (teller at boundary or not a valid move)
            end
          end
          
          // Prepare next iteration: one more swap budget
          target_swaps = target_swaps + 1;
          next_state = COUNT_VOTES;
        end else begin
          // Safety: should not reach here; fallback
          is_impossible = 1'b1;
          done = 1'b1;
          next_state = DONE;
        end
      end

      DONE: begin
        // Hold outputs; wait for start or reset
        done = 1'b1;
        if (start) begin
          // Restart if requested again
          next_state = INIT;
        end else begin
          next_state = DONE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule