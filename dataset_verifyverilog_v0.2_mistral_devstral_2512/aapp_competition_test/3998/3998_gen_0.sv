module rating_equalizer (
  input clk,
  input rst_n,
  input start,
  input [3:0] r0,
  input [3:0] r1,
  input [3:0] r2,
  input [3:0] r3,
  output reg [3:0] final_rating,
  output reg [5:0] match_count,
  output reg [3:0] match_friend0,
  output reg [3:0] match_friend1,
  output reg [3:0] match_friend2,
  output reg [3:0] match_friend3,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CHECK,
    UPDATE,
    DONE
  } state_t;

  // Internal registers
  reg [1:0] state;
  reg [3:0] current_r0, current_r1, current_r2, current_r3;
  reg [5:0] current_match_count;
  reg [3:0] current_match_friend0, current_match_friend1, current_match_friend2, current_match_friend3;
  reg [3:0] max_rating;
  reg [3:0] friend_mask;
  reg [1:0] counter;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_r0 <= 0;
      current_r1 <= 0;
      current_r2 <= 0;
      current_r3 <= 0;
      current_match_count <= 0;
      current_match_friend0 <= 0;
      current_match_friend1 <= 0;
      current_match_friend2 <= 0;
      current_match_friend3 <= 0;
      max_rating <= 0;
      friend_mask <= 0;
      counter <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CHECK;
            current_r0 <= r0;
            current_r1 <= r1;
            current_r2 <= r2;
            current_r3 <= r3;
            current_match_count <= 0;
            current_match_friend0 <= 0;
            current_match_friend1 <= 0;
            current_match_friend2 <= 0;
            current_match_friend3 <= 0;
            done <= 0;
          end
        end
        CHECK: begin
          // Find max rating and friend mask
          max_rating <= (current_r0 > current_r1) ? current_r0 : current_r1;
          max_rating <= (max_rating > current_r2) ? max_rating : current_r2;
          max_rating <= (max_rating > current_r3) ? max_rating : current_r3;

          friend_mask <= 0;
          if (current_r0 == max_rating) friend_mask[0] <= 1;
          if (current_r1 == max_rating) friend_mask[1] <= 1;
          if (current_r2 == max_rating) friend_mask[2] <= 1;
          if (current_r3 == max_rating) friend_mask[3] <= 1;

          // Check if all ratings are equal
          if ((current_r0 == current_r1) && (current_r1 == current_r2) && (current_r2 == current_r3)) begin
            state <= DONE;
          end else if (current_match_count == 63) begin
            state <= DONE;
          end else begin
            state <= UPDATE;
          end
        end
        UPDATE: begin
          // Determine which friends to update
          if (friend_mask >= 4'b1110) begin
            // 3 or more friends have max rating
            if (current_r0 == max_rating && current_r0 > 0) current_r0 <= current_r0 - 1;
            if (current_r1 == max_rating && current_r1 > 0) current_r1 <= current_r1 - 1;
            if (current_r2 == max_rating && current_r2 > 0) current_r2 <= current_r2 - 1;
            if (current_r3 == max_rating && current_r3 > 0) current_r3 <= current_r3 - 1;

            // Update match_friend signals
            current_match_friend0 <= friend_mask[0] ? 1 : 0;
            current_match_friend1 <= friend_mask[1] ? 1 : 0;
            current_match_friend2 <= friend_mask[2] ? 1 : 0;
            current_match_friend3 <= friend_mask[3] ? 1 : 0;
          end else begin
            // Find top 2 friends
            reg [3:0] top_friends = 0;
            reg [3:0] temp_mask = friend_mask;
            reg [1:0] count = 0;

            for (int i = 0; i < 4; i++) begin
              if (temp_mask[i] && count < 2) begin
                top_friends[i] = 1;
                count = count + 1;
              end
            end

            // Update ratings
            if (top_friends[0] && current_r0 > 0) current_r0 <= current_r0 - 1;
            if (top_friends[1] && current_r1 > 0) current_r1 <= current_r1 - 1;
            if (top_friends[2] && current_r2 > 0) current_r2 <= current_r2 - 1;
            if (top_friends[3] && current_r3 > 0) current_r3 <= current_r3 - 1;

            // Update match_friend signals
            current_match_friend0 <= top_friends[0];
            current_match_friend1 <= top_friends[1];
            current_match_friend2 <= top_friends[2];
            current_match_friend3 <= top_friends[3];
          end

          // Increment match count
          current_match_count <= current_match_count + 1;
          state <= CHECK;
        end
        DONE: begin
          final_rating <= current_r0; // All ratings are equal
          match_count <= current_match_count;
          match_friend0 <= current_match_friend0;
          match_friend1 <= current_match_friend1;
          match_friend2 <= current_match_friend2;
          match_friend3 <= current_match_friend3;
          done <= 1;
        end
      endcase
    end
  end

endmodule