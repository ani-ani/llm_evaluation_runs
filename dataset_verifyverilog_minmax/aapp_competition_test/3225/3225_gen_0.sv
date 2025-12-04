module candidate_queue_processor(
  input clk,                                // clock
  input rst_n,                              // active-low reset
  input start,                              // start processing
  input [7:0] initial_values [0:7],         // 8 candidates with 8-bit values each
  output reg done,                          // high when processing complete
  output reg [3:0] round_count,             // number of rounds completed
  output reg [7:0] final_queue [0:7],       // final retained candidates
  output reg [3:0] queue_size               // size of final queue
);

  // Working storage for candidates during processing
  reg [7:0] candidates [0:7];
  reg [3:0] num_candidates;

  // FSM state
  typedef enum logic [1:0] { IDLE = 2'b00, LOAD = 2'b01, PROCESS = 2'b10 } state_t;
  state_t state, next_state;

  // Elimination mask for the current round
  reg [7:0] elim_mask;

  // Next-round state
  reg [7:0] next_candidates [0:7];
  reg [3:0] next_num_candidates;
  reg [7:0] next_elim_mask;
  reg [3:0] next_round_count;

  integer i, j;

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      round_count <= 4'd0;
      queue_size <= 4'd0;
      for (i = 0; i < 8; i++) begin
        candidates[i] <= 8'd0;
        final_queue[i] <= 8'd0;
      end
      num_candidates <= 4'd0;
      elim_mask <= 8'd0;
    end else begin
      state <= next_state;
      // Outputs and working regs
      done <= (next_state == IDLE) ? 1'b0 : (next_state == PROCESS ? 1'b0 : 1'b0);
      round_count <= next_round_count;
      queue_size <= next_num_candidates;
      for (j = 0; j < 8; j++) begin
        candidates[j] <= next_candidates[j];
        final_queue[j] <= next_candidates[j]; // hold last computed queue during PROCESS
      end
      num_candidates <= next_num_candidates;
      elim_mask <= next_elim_mask;
    end
  end

  // Combinational next-state logic
  always_comb begin
    // Defaults (preserve current values)
    next_state = state;
    next_round_count = round_count;
    next_num_candidates = num_candidates;
    next_elim_mask = elim_mask;
    for (i = 0; i < 8; i++) next_candidates[i] = candidates[i];

    case (state)
      IDLE: begin
        next_round_count = 4'd0;
        next_num_candidates = 4'd0;
        next_elim_mask = 8'd0;
        for (i = 0; i < 8; i++) next_candidates[i] = 8'd0;
        done = 1'b0;
        if (start) begin
          next_state = LOAD;
        end
      end

      LOAD: begin
        // Load initial values
        for (i = 0; i < 8; i++) next_candidates[i] = initial_values[i];
        next_num_candidates = 4'd8;
        next_elim_mask = 8'd0;
        next_round_count = 4'd0;
        next_state = PROCESS;
      end

      PROCESS: begin
        // Compute elimination for this round
        next_elim_mask = 8'd0;
        for (i = 0; i < 8; i++) begin
          if (candidates[i] !== 8'dX) begin
            if (i == 0) begin
              // Only right neighbor
              if (candidates[1] !== 8'dX && candidates[1] > candidates[i])
                next_elim_mask[i] = 1'b1;
            end else if (i == 7) begin
              // Only left neighbor
              if (candidates[6] !== 8'dX && candidates[6] > candidates[i])
                next_elim_mask[i] = 1'b1;
            end else begin
              // Both neighbors
              if ((candidates[i-1] !== 8'dX && candidates[i-1] > candidates[i]) ||
                  (candidates[i+1] !== 8'dX && candidates[i+1] > candidates[i]))
                next_elim_mask[i] = 1'b1;
            end
          end
        end

        // Compact the array (remove marked candidates)
        next_num_candidates = 4'd0;
        for (i = 0; i < 8; i++) begin
          if (candidates[i] !== 8'dX && !next_elim_mask[i]) begin
            next_candidates[next_num_candidates] = candidates[i];
            next_num_candidates = next_num_candidates + 1;
          end
        end
        // Fill remainder with don't-cares (not required but clean)
        for (i = next_num_candidates; i < 8; i++) begin
          next_candidates[i] = 8'dX;
        end

        // Decide next state and count rounds
        if (next_elim_mask == 8'd0 || next_num_candidates <= 4'd1) begin
          // No eliminations or only one candidate remains -> done
          next_state = IDLE;        // Will be captured in next cycle
          next_round_count = round_count; // No new round completed
          done = 1'b1;             // Mark completion next cycle
        end else begin
          // At least one elimination occurred -> another round follows
          next_state = PROCESS;
          next_round_count = round_count + 4'd1;
          done = 1'b0;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule
