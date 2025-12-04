module numeric_string_sorter (
  input clk,
  input rst_n,
  input start,
  input [11:0] numbers [7:0],
  output reg [11:0] sorted [7:0],
  output reg done
);
  
  // States
  enum reg [1:0] {
    IDLE,
    COMPARE,
    SWAP,
    DONE
  } state, next_state;

  reg [11:0] sorted_arr [7:0];  // Working array
  reg [2:0] index_counter;     // Current index (0-6)
  reg [2:0] pass_counter;      // Pass counter (0-7)
  reg swapped_flag;            // Swap detected flag

  // FSM transition logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      pass_counter <= 3'd0;
      index_counter <= 3'd0;
      swapped_flag <= 1'b0;
      for (int i=0; i<8; i++) sorted_arr[i] <= 12'sb0;
    end
    else begin
      state <= next_state;

      case(state)
        IDLE: begin
          if (start) begin
            sorted_arr <= numbers;
            pass_counter <= 3'd0;
            done <= 1'b0;
          end
        end
        
        COMPARE: begin
          if (sorted_arr[index_counter] > sorted_arr[index_counter+1]) begin
            next_state <= SWAP;
          end
          else begin
            if (index_counter < (6 - pass_counter)) begin
              index_counter <= index_counter + 3'd1;
              next_state <= COMPARE;
            end
            else begin
              index_counter <= 3'd0;
              pass_counter <= pass_counter + 3'd1;
              next_state <= swapped_flag ? COMPARE : DONE;
              swapped_flag <= 1'b0;
            end
          end
        end
        
        SWAP: begin
          sorted_arr[index_counter] <= sorted_arr[index_counter+1];
          sorted_arr[index_counter+1] <= sorted_arr[index_counter];
          swapped_flag <= 1'b1;
          
          if (index_counter < (6 - pass_counter)) begin
            index_counter <= index_counter + 3'd1;
            next_state <= COMPARE;
          end
          else begin
            index_counter <= 3'd0;
            pass_counter <= pass_counter + 3'd1;
            next_state <= swapped_flag ? COMPARE : DONE;
            swapped_flag <= 1'b0;
          end
        end
        
        DONE: begin
          sorted <= sorted_arr;
          done <= 1'b1;
          next_state <= IDLE;
        end
      endcase
    end
  end

  // FSM state transition
  always_comb begin
    next_state = state;
    case(state)
      IDLE: if (start) next_state = COMPARE;
      DONE: next_state = IDLE;
      default: ;
    endcase
  end
endmodule