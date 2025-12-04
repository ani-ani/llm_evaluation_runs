module first_non_repeat (
  input clk,
  input rst_n,
  input start,
  input [7:0] str [0:7],
  output reg [7:0] result,
  output reg done
);
  
  typedef enum {IDLE, FIRST_PASS, RELOAD, SECOND_PASS, DONE_ST} state_t;
  state_t state, next_state;
  
  reg [3:0] cycle_cnt;
  reg [7:0] buffer_reg [0:7];
  reg [7:0] shift_reg [0:7];
  reg [3:0] freq_counter [0:255];
  reg found;
  
  wire [7:0] current_char;
  
  assign current_char = shift_reg[0];
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_cnt <= 4'd0;
      result <= 8'd0;
      done <= 1'b0;
      found <= 1'b0;
      
      for (int i=0; i<8; i=i+1) begin
        buffer_reg[i] <= 8'd0;
        shift_reg[i] <= 8'd0;
      end
      
      for (int i=0; i<256; i=i+1)
        freq_counter[i] <= 4'd0;
    
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          cycle_cnt <= 4'd0;
          done <= 1'b0;
          if (start) begin
            for (int i=0; i<8; i=i+1)
              buffer_reg[i] <= str[i];
            
            shift_reg[0] <= str[0];
            shift_reg[1] <= str[1];
            shift_reg[2] <= str[2];
            shift_reg[3] <= str[3];
            shift_reg[4] <= str[4];
            shift_reg[5] <= str[5];
            shift_reg[6] <= str[6];
            shift_reg[7] <= str[7];
          end
        end
        
        FIRST_PASS: begin
          cycle_cnt <= cycle_cnt + 1;
          freq_counter[current_char] <= freq_counter[current_char] + 1;
          
          shift_reg[0] <= shift_reg[1];
          shift_reg[1] <= shift_reg[2];
          shift_reg[2] <= shift_reg[3];
          shift_reg[3] <= shift_reg[4];
          shift_reg[4] <= shift_reg[5];
          shift_reg[5] <= shift_reg[6];
          shift_reg[6] <= shift_reg[7];
          shift_reg[7] <= 8'd0;
        end
        
        RELOAD: begin
          cycle_cnt <= 4'd0;
          shift_reg[0] <= buffer_reg[0];
          shift_reg[1] <= buffer_reg[1];
          shift_reg[2] <= buffer_reg[2];
          shift_reg[3] <= buffer_reg[3];
          shift_reg[4] <= buffer_reg[4];
          shift_reg[5] <= buffer_reg[5];
          shift_reg[6] <= buffer_reg[6];
          shift_reg[7] <= buffer_reg[7];
        end
        
        SECOND_PASS: begin
          cycle_cnt <= cycle_cnt + 1;
          
          if (!found && freq_counter[current_char] == 1) begin
            result <= current_char;
            found <= 1'b1;
          end
          
          shift_reg[0] <= shift_reg[1];
          shift_reg[1] <= shift_reg[2];
          shift_reg[2] <= shift_reg[3];
          shift_reg[3] <= shift_reg[4];
          shift_reg[4] <= shift_reg[5];
          shift_reg[5] <= shift_reg[6];
          shift_reg[6] <= shift_reg[7];
          shift_reg[7] <= 8'd0;
        end
        
        DONE_ST: begin
          done <= 1'b1;
          result <= (found) ? result : 8'd0;
          found <= 1'b0;
        end
      endcase
    end
  end
  
  always_comb begin
    next_state = state;
    case (state)
      IDLE: next_state = (start) ? FIRST_PASS : IDLE;
      
      FIRST_PASS: begin
        if (cycle_cnt == 7)
          next_state = RELOAD;
        else
          next_state = FIRST_PASS;
      end
      
      RELOAD: next_state = SECOND_PASS;
      
      SECOND_PASS: begin
        if (cycle_cnt == 7)
          next_state = DONE_ST;
        else
          next_state = SECOND_PASS;
      end
      
      DONE_ST: next_state = IDLE;
    endcase
  end
endmodule