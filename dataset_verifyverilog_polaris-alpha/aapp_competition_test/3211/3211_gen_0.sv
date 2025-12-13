module vote_swap_optimizer(
  input clk,
  input rst_n,
  input start,
  input [31:0] input_str,
  output reg [4:0] min_swaps,
  output reg is_impossible,
  output reg done
);

  // Encoding: 0=teller, 1=party1, 2=party2
  // 16 positions, 2 bits each: pos[i] = input_str[2*i+1:2*i]

  // State machine
  localparam IDLE          = 3'd0;
  localparam INIT          = 3'd1;
  localparam MOVE_TELLERS  = 3'd2;
  localparam COUNT_VOTES   = 3'd3;
  localparam COMPARE_SCORES= 3'd4;
  localparam DONE          = 3'd5;

  reg [2:0] state, next_state;

  // 100-cycle latency tracking
  reg [6:0] cycle_cnt; // counts up to at least 100

  // Working array for configuration (packed 2-bit per position)
  reg [1:0] pos [0:15];

  // Original decoded input for reference (static snapshot at start)
  reg [1:0] base_pos [0:15];

  // Teller positions tracking
  reg [3:0] teller_idx [0:15]; // store indices of all tellers in base configuration
  reg [3:0] teller_count;      // number of tellers

  // Swap exploration
  reg [4:0] current_swaps;     // current swap depth under test
  reg [9:0] swaps_pattern;     // generic pattern index for search (not exhaustive optimal algorithm but placeholder)

  // Vote and point counters
  reg [7:0] p1_votes;
  reg [7:0] p2_votes;
  reg [3:0] p1_points;
  reg [3:0] p2_points;

  // Best solution tracking
  reg        found_solution;
  reg [4:0]  best_swaps;

  integer i;

  // Decode input_str into base_pos when start asserted in INIT
  // Sequential state/outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= IDLE;
      cycle_cnt      <= 7'd0;
      done           <= 1'b0;
      is_impossible  <= 1'b0;
      min_swaps      <= 5'd0;
      found_solution <= 1'b0;
      best_swaps     <= 5'd31;
      current_swaps  <= 5'd0;
      swaps_pattern  <= 10'd0;
      teller_count   <= 4'd0;
      p1_votes       <= 8'd0;
      p2_votes       <= 8'd0;
      p1_points      <= 4'd0;
      p2_points      <= 4'd0;
      for (i = 0; i < 16; i = i + 1) begin
        base_pos[i] <= 2'd0;
        pos[i]      <= 2'd0;
        teller_idx[i]<=4'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done          <= 1'b0;
          is_impossible <= 1'b0;
          if (start) begin
            cycle_cnt      <= 7'd0;
            found_solution <= 1'b0;
            best_swaps     <= 5'd31;
            current_swaps  <= 5'd0;
            swaps_pattern  <= 10'd0;
            teller_count   <= 4'd0;
            // snapshot and decode input
            for (i = 0; i < 16; i = i + 1) begin
              base_pos[i] <= input_str[2*i +: 2];
            end
          end
        end

        INIT: begin
          // identify teller positions from base_pos
          teller_count <= 4'd0;
          for (i = 0; i < 16; i = i + 1) begin
            if (base_pos[i] == 2'd0) begin
              teller_idx[teller_count] <= i[3:0];
              teller_count <= teller_count + 1'b1;
            end
          end
          // initialize working pos = base_pos
          for (i = 0; i < 16; i = i + 1) begin
            pos[i] <= base_pos[i];
          end
          // reset counters for first evaluation
          p1_votes  <= 8'd0;
          p2_votes  <= 8'd0;
          p1_points <= 4'd0;
          p2_points <= 4'd0;
        end

        MOVE_TELLERS: begin
          // Placeholder move strategy: use swaps_pattern bits to apply a deterministic
          // sequence of adjacent swaps on working pos to approximate search space.
          // Each bit (up to 10) controls one potential swap between positions (2*i,2*i+1).
          // current_swaps grows with swaps_pattern popcount implicitly by sequence.

          // Reset working config to base for each new pattern depth
          for (i = 0; i < 16; i = i + 1) begin
            pos[i] <= base_pos[i];
          end

          current_swaps <= 5'd0;
          // Apply up to 10 conditional adjacent swaps to form candidate
          for (i = 0; i < 10; i = i + 1) begin
            if (swaps_pattern[i]) begin
              if ((2*i) < 15) begin
                // swap pos[2*i] and pos[2*i+1]
                {pos[2*i], pos[2*i+1]} <= {pos[2*i+1], pos[2*i]};
                current_swaps <= current_swaps + 1'b1;
              end
            end
          end

          // reset counting for this candidate
          p1_votes  <= 8'd0;
          p2_votes  <= 8'd0;
          p1_points <= 4'd0;
          p2_points <= 4'd0;
        end

        COUNT_VOTES: begin
          // Simulate counting: scan positions left to right
          // Assume each teller (0) gives 1 point to party with more votes so far.
          // If tie, no points.
          p1_votes  <= 8'd0;
          p2_votes  <= 8'd0;
          p1_points <= 4'd0;
          p2_points <= 4'd0;
          for (i = 0; i < 16; i = i + 1) begin
            if (pos[i] == 2'd1) begin
              p1_votes <= p1_votes + 1'b1;
            end else if (pos[i] == 2'd2) begin
              p2_votes <= p2_votes + 1'b1;
            end else if (pos[i] == 2'd0) begin
              if (p1_votes > p2_votes)
                p1_points <= p1_points + 1'b1;
              else if (p2_votes > p1_votes)
                p2_points <= p2_points + 1'b1;
            end
          end
        end

        COMPARE_SCORES: begin
          // Check if candidate yields victory for party1 and track minimal swaps
          if (p1_points > p2_points) begin
            if (!found_solution || (current_swaps < best_swaps)) begin
              found_solution <= 1'b1;
              best_swaps     <= current_swaps;
            end
          end

          // Move to next pattern until 100 cycles done
          if (cycle_cnt < 7'd99) begin
            swaps_pattern <= swaps_pattern + 1'b1;
            cycle_cnt     <= cycle_cnt + 1'b1;
          end
        end

        DONE: begin
          done <= 1'b1;
          if (found_solution) begin
            min_swaps     <= best_swaps;
            is_impossible <= 1'b0;
          end else begin
            min_swaps     <= 5'd0;
            is_impossible <= 1'b1;
          end
        end

        default: ;
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
        next_state = MOVE_TELLERS;
      end

      MOVE_TELLERS: begin
        next_state = COUNT_VOTES;
      end

      COUNT_VOTES: begin
        next_state = COMPARE_SCORES;
      end

      COMPARE_SCORES: begin
        if (cycle_cnt == 7'd99)
          next_state = DONE;
        else
          next_state = MOVE_TELLERS;
      end

      DONE: begin
        if (!start) // wait for start deassert then ready for next
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule