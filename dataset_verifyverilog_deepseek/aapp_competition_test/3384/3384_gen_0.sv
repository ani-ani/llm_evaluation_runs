module handsome_number_finder(
  input clk,
  input rst_n,
  input start,
  input [13:0] num_in,
  output reg [13:0] result1,
  output reg [13:0] result2,
  output reg valid,
  output reg tie_flag
);
  
  // FSM States
  typedef enum logic [2:0] {
    IDLE,
    INITIAL_CHECK,
    SEARCH,
    EVALUATE,
    DONE
  } state_t;
  
  reg [2:0] state, next_state;
  reg [13:0] initial_num;
  reg [13:0] down_count, up_count;
  reg found_down, found_up;
  reg [13:0] candidate_down, candidate_up;
  
  // Handsome check function
  function automatic logic is_handsome(input [13:0] num);
    logic [3:0] d0, d1, d2, d3;
    begin
      if (num < 10) return 1'b1;
      
      d0 = num % 10;
      d1 = (num / 10) % 10;
      d2 = (num / 100) % 10;
      d3 = num / 1000;
      
      return (d3 <= 9) && (d2 <= 9) && (d1 <= 9) && (d0 <= 9) &&
             (d3 % 2 != d2 % 2) &&
             (d2 % 2 != d1 % 2) &&
             (d1 % 2 != d0 % 2);
    end
  endfunction
  
  // FSM logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result1 <= 14'd0;
      result2 <= 14'd0;
      valid <= 1'b0;
      tie_flag <= 1'b0;
      initial_num <= 14'd0;
      down_count <= 14'd0;
      up_count <= 14'd0;
      found_down <= 1'b0;
      found_up <= 1'b0;
      candidate_down <= 14'd0;
      candidate_up <= 14'd0;
    end else begin
      state <= next_state;
      
      case (state)
        IDLE: begin
          valid <= 1'b0;
          tie_flag <= 1'b0;
          if (start) begin
            initial_num <= num_in;
            next_state <= INITIAL_CHECK;
          end
        end
        
        INITIAL_CHECK: begin
          if (is_handsome(initial_num)) begin
            result1 <= initial_num;
            result2 <= initial_num;
            tie_flag <= 1'b0;
            valid <= 1'b1;
            next_state <= DONE;
          end else begin
            down_count <= initial_num - 14'd1;
            up_count <= initial_num + 14'd1;
            found_down <= 1'b0;
            found_up <= 1'b0;
            candidate_down <= 14'd0;
            candidate_up <= 14'd0;
            next_state <= SEARCH;
          end
        end
        
        SEARCH: begin
          if (!found_down && down_count >= 10) begin
            if (is_handsome(down_count)) begin
              candidate_down <= down_count;
              found_down <= 1'b1;
            end else begin
              down_count <= down_count - 14'd1;
            end
          end else if (down_count < 10) begin
            candidate_down <= down_count;
            found_down <= 1'b1;
          end
          
          if (!found_up && up_count <= 14'd9999) begin
            if (is_handsome(up_count)) begin
              candidate_up <= up_count;
              found_up <= 1'b1;
            end else begin
              up_count <= up_count + 14'd1;
            end
          end else if (up_count > 14'd9999) begin
            found_up <= 1'b1; // No up candidate found
          end
          
          if ((found_down || down_count <= 14'd10) && (found_up || up_count >= 14'd9999))
            next_state <= EVALUATE;
          else
            next_state <= SEARCH;
        end
        
        EVALUATE: begin
          if (found_down && found_up) begin
            if ((initial_num - candidate_down) == (candidate_up - initial_num)) begin
              result1 <= (candidate_down < candidate_up) ? candidate_down : candidate_up;
              result2 <= (candidate_down < candidate_up) ? candidate_up : candidate_down;
              tie_flag <= 1'b1;
            end else if ((initial_num - candidate_down) < (candidate_up - initial_num)) begin
              result1 <= candidate_down;
              tie_flag <= 1'b0;
            end else begin
              result1 <= candidate_up;
              tie_flag <= 1'b0;
            end
          end else if (found_down) begin
            result1 <= candidate_down;
            tie_flag <= 1'b0;
          end else if (found_up) begin
            result1 <= candidate_up;
            tie_flag <= 1'b0;
          end
          valid <= 1'b1;
          next_state <= DONE;
        end
        
        DONE: begin
          next_state <= IDLE;
        end
      endcase
    end
  end
endmodule