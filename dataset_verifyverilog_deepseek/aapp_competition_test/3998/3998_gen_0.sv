module team_rating_equalizer(
  input clk,
  input rst_n,
  input start,
  input [7:0] r0,
  input [7:0] r1,
  input [7:0] r2,
  input [7:0] r3,
  output reg [7:0] final_R,
  output reg [3:0] match_vec,
  output reg valid_match,
  output reg done
);

  typedef enum logic [2:0] { S_INIT, S_FIND_MAX, S_UPDATE, S_CHECK, S_DONE } state_t;
  state_t state, next_state;
  
  reg [7:0] curr_ratings [0:3];
  wire [7:0] max_val, min_val;
  wire [3:0] selected_players;
  wire all_equal;
  
  // Max and min calculation
  assign max_val = (curr_ratings[0] >= curr_ratings[1] && curr_ratings[0] >= curr_ratings[2] && curr_ratings[0] >= curr_ratings[3]) ? curr_ratings[0] :
                  (curr_ratings[1] >= curr_ratings[2] && curr_ratings[1] >= curr_ratings[3]) ? curr_ratings[1] :
                  (curr_ratings[2] >= curr_ratings[3]) ? curr_ratings[2] : curr_ratings[3];
  
  assign min_val = (curr_ratings[0] <= curr_ratings[1] && curr_ratings[0] <= curr_ratings[2] && curr_ratings[0] <= curr_ratings[3]) ? curr_ratings[0] :
                  (curr_ratings[1] <= curr_ratings[2] && curr_ratings[1] <= curr_ratings[3]) ? curr_ratings[1] :
                  (curr_ratings[2] <= curr_ratings[3]) ? curr_ratings[2] : curr_ratings[3];
  
  assign all_equal = (max_val == min_val);
  
  // Player selection logic
  reg [2:0] current_count;
  reg [7:0] current_max;
  reg [7:0] next_max;
  integer i, max_player_index;
  
  always_comb begin
    current_max = max_val;
    current_count = 0;
    for (i=0; i<4; i++) begin
      if (curr_ratings[i] == current_max) current_count += 1;
    end
    
    if (current_count >= 2) begin
      selected_players = { curr_ratings[3] == current_max, curr_ratings[2] == current_max, 
                          curr_ratings[1] == current_max, curr_ratings[0] == current_max };
    end else begin
      // Find next_max and max_player_index
      max_player_index = 0;
      for (i=0; i<4; i++) begin
        if (curr_ratings[i] == current_max) max_player_index = i;
      end
      
      next_max = 0;
      for (i=0; i<4; i++) begin
        if (i != max_player_index) begin
          if (curr_ratings[i] > next_max) next_max = curr_ratings[i];
        end
      end
      
      selected_players = 0;
      for (i=0; i<4; i++) begin
        if ((curr_ratings[i] == current_max) || (curr_ratings[i] == next_max)) begin
          selected_players[i] = 1'b1;
        end
      end
    end
  end
  
  // FSM transitions
  always_comb begin
    next_state = state;
    case (state)
      S_INIT: if (start) next_state = S_FIND_MAX;
      S_FIND_MAX: next_state = S_UPDATE;
      S_UPDATE: next_state = S_CHECK;
      S_CHECK: next_state = (all_equal) ? S_DONE : S_FIND_MAX;
      S_DONE: if (start) next_state = S_FIND_MAX;
    endcase
  end
  
  // FSM outputs and registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_INIT;
      curr_ratings[0] <= 8'b0;
      curr_ratings[1] <= 8'b0;
      curr_ratings[2] <= 8'b0;
      curr_ratings[3] <= 8'b0;
      final_R <= 8'b0;
      match_vec <= 4'b0;
      valid_match <= 1'b0;
      done <= 1'b0;
    end
    else begin
      valid_match <= 1'b0;
      
      case (state)
        S_INIT: begin
          done <= 1'b0;
          if (start) begin
            curr_ratings[0] <= r0;
            curr_ratings[1] <= r1;
            curr_ratings[2] <= r2;
            curr_ratings[3] <= r3;
            state <= S_FIND_MAX;
          end
        end
        
        S_FIND_MAX: begin
          state <= S_UPDATE;
        end
        
        S_UPDATE: begin
          for (i=0; i<4; i++) begin
            if (selected_players[i] && curr_ratings[i] > 0) 
              curr_ratings[i] <= curr_ratings[i] - 1;
          end
          match_vec <= selected_players;
          valid_match <= 1'b1;
          state <= S_CHECK;
        end
        
        S_CHECK: begin
          state <= next_state;
        end
        
        S_DONE: begin
          final_R <= curr_ratings[0];
          done <= 1'b1;
          if (start) begin
            curr_ratings[0] <= r0;
            curr_ratings[1] <= r1;
            curr_ratings[2] <= r2;
            curr_ratings[3] <= r3;
            state <= S_FIND_MAX;
          end
        end
      endcase
    end
  end
endmodule