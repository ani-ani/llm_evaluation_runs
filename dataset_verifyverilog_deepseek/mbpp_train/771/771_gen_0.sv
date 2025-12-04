module balance_checker(
  input clk,
  input rst_n,
  input start,
  input [15:0][2:0] expr,
  output reg result,
  output reg done
);
  
  typedef enum logic [1:0] {IDLE, PROCESSING, DONE_ST} state_t;
  state_t state, next_state;
  
  reg [2:0] stack [0:7];
  reg [2:0] sp;
  reg [3:0] cnt;
  reg err_flag;
  reg [2:0] current_char;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      sp <= 3'd0;
      cnt <= 4'd0;
      err_flag <= 1'b0;
      result <= 1'b0;
      done <= 1'b0;
      for (int i = 0; i < 8; i++) stack[i] <= 3'd0;
    end else begin
      state <= next_state;
      
      case (state)
        IDLE: begin
          if (start) begin
            sp <= 3'd0;
            cnt <= 4'd0;
            err_flag <= 1'b0;
            done <= 1'b0;
          end
        end
        
        PROCESSING: begin
          current_char <= expr[cnt];
          
          case (current_char)
            // Open brackets - push
            3'b000, 3'b010, 3'b100: begin
              if (sp < 3'd7) begin
                stack[sp] <= current_char;
                sp <= sp + 1'b1;
              end else begin
                err_flag <= 1'b1;
              end
            end
            
            // Close brackets - check
            3'b001: begin // ')'
              if (sp == 3'd0 || stack[sp-1] != 3'b000) 
                err_flag <= 1'b1;
              else 
                sp <= sp - 1'b1;
            end
            3'b011: begin // '}'
              if (sp == 3'd0 || stack[sp-1] != 3'b010)
                err_flag <= 1'b1;
              else
                sp <= sp - 1'b1;
            end
            3'b101: begin // ']'
              if (sp == 3'd0 || stack[sp-1] != 3'b100)
                err_flag <= 1'b1;
              else
                sp <= sp - 1'b1;
            end
            
            default: ; // Ignore others
          endcase
          
          cnt <= cnt + 1'b1;
        end
        
        DONE_ST: begin
          result <= (sp == 3'd0) && !err_flag;
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
  
  always_comb begin
    next_state = state;
    case (state)
      IDLE: next_state = start ? PROCESSING : IDLE;
      PROCESSING: next_state = (cnt == 4'd15) ? DONE_ST : PROCESSING;
      DONE_ST: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end
  
endmodule