module pattern_matcher (
   input clk,
   input rst_n, // active low
   input start,
   input [7:0] char_in,
   input valid_in,
   output reg match,
   output reg done);

// Internal registers
reg [2:0] state;
reg [3:0] counter;

// State definitions
localparam IDLE = 3'd0;
localparam S_A = 1;
localparam S_B1 = 2;
localparam S_B2 = 3;
localparam S_B3 = 4;
localparam MATCH_STATE = 5;
localparam DONE_STATE = 6;

// Outputs assigned from state
reg match, done;

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      counter <= 4'd0;
      match <= 1'b0;
      done <= 1'b0;
   end else begin
      if (start) begin
         state <= IDLE;
         counter <= 4'd0;
         match <= 1'b0;
         done <= 1'b0;
      end else begin
         int char_val;
         int next_state_candidate;
         // Default: no change
         reg [2:0] next_state;
         reg [3:0] next_counter;
         next_state = state;
         next_counter = counter;
         if (valid_in && (state != DONE_STATE && state != MATCH_STATE)) begin
            char_val = char_in;
            // case for next_state_candidate
            case (state)
               IDLE: next_state_candidate = IDLE;
               S_A: begin
                  if (char_val == 8'h61) next_state_candidate = S_B1;
                  else next_state_candidate = S_A;
               end
               S_B1: begin
                  if (char_val == 8'h62) next_state_candidate = S_B2;
                  else if (char_val == 8'h61) next_state_candidate = S_B1;
                  else next_state_candidate = S_A;
               end
               S_B2: begin
                  if (char_val == 8'h62) next_state_candidate = S_B3;
                  else if (char_val == 8'h61) next_state_candidate = S_B1;
                  else next_state_candidate = S_A;
               end
               S_B3: begin
                  if (char_val == 8'h62) next_state_candidate = MATCH_STATE;
                  else if (char_val == 8'h61) next_state_candidate = S_B1;
                  else next_state_candidate = S_A;
               end
               MATCH_STATE: next_state_candidate = MATCH_STATE;
               DONE_STATE: next_state_candidate = DONE_STATE;
               default: next_state_candidate = IDLE;
            endcase
            // Determine next_state and next_counter
            if (next_state_candidate == MATCH_STATE) begin
               next_state = MATCH_STATE;
               next_counter = counter + 1;
            end else begin
               next_counter = counter + 1;
               if (next_counter == 15) begin
                  next_state = DONE_STATE;
               end else begin
                  next_state = next_state_candidate;
               end
            end
         end // valid_in condition
      end // else of start
      // Update registers
      state <= next_state;
      counter <= next_counter;
      match <= (next_state == MATCH_STATE);
      done <= (next_state == DONE_STATE);
   end
endmodule