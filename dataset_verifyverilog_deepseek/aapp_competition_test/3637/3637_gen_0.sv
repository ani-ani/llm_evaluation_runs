module pizza_topping_selector(input clk,
                    input rst_n,
                    input start,
                    input [1:0] num_friends,
                    input [71:0] friend_wishes,
                    output reg [7:0] selected_toppings,
                    output reg done);

  typedef enum logic [1:0] { IDLE, CHECK, COMPLETE } state_t;

  state_t state_reg, state_next;
  reg [7:0] current_candidate_reg, current_candidate_next;
  reg [1:0] num_friends_reg;
  reg [71:0] friend_wishes_reg;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_reg <= IDLE;
      current_candidate_reg <= 8'd0;
      selected_toppings <= 8'd0;
      done <= 1'b0;
      num_friends_reg <= 2'd0;
      friend_wishes_reg <= 72'd0;
    end else begin
      state_reg <= state_next;
      current_candidate_reg <= current_candidate_next;
      if (state_reg == IDLE && start) begin
        num_friends_reg <= num_friends;
        friend_wishes_reg <= friend_wishes;
      end
    end
  end
  
  always_comb begin
    state_next = state_reg;
    current_candidate_next = current_candidate_reg;
    done = 1'b0;
    selected_toppings = 8'd0;
    
    case (state_reg)
      IDLE: begin
        if (start) begin
          state_next = CHECK;
          current_candidate_next = 8'd0;
        end
      end
      
      CHECK: begin
        logic all_friends_ok = 1'b1;
        for (int f = 0; f <= num_friends_reg; f++) begin
          logic [17:0] friend_field = friend_wishes_reg[(f*18) +: 18];
          logic [1:0] wish_count = friend_field[17:16];
          logic [2:0] total_wishes = wish_count + 1;
          logic [2:0] satisfied_count = 0;
          
          for (int w = 0; w < 4; w++) begin
            if (w < total_wishes) begin
              logic [3:0] wish_slice = friend_field[15 - (4*w) -:4];
              logic wish_type = wish_slice[3];
              logic [2:0] topping_id = wish_slice[2:0];
              if ((wish_type && current_candidate_reg[topping_id]) || (!wish_type && !current_candidate_reg[topping_id])) satisfied_count++;
            end
          end
          
          if (3 * satisfied_count <= total_wishes) all_friends_ok = 1'b0;
        end
        
        if (all_friends_ok) begin
          state_next = COMPLETE;
          done = 1'b1;
          selected_toppings = current_candidate_reg;
        end else if (current_candidate_reg == 8'hFF) begin
          state_next = COMPLETE;
          done = 1'b1;
          selected_toppings = current_candidate_reg;
        end else begin
          current_candidate_next = current_candidate_reg + 1;
        end
      end
      
      COMPLETE: begin
        done = 1'b1;
        selected_toppings = selected_toppings;
        state_next = COMPLETE;
      end
      
      default: state_next = IDLE;
    endcase
  end
endmodule