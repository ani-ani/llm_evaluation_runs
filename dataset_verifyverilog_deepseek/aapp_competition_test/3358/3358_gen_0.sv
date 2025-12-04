module number_display_processor(input clk, input rst_n, input start, input [7:0] input_num, output reg [7:0] display_out, output reg done);
  typedef enum logic [1:0] {IDLE, FETCH, EXECUTE, DONE} state_t;
  state_t current_state, next_state;
  reg [7:0] A, X, Y;
  reg [7:0] stack [0:39];
  reg [5:0] sp;
  reg [7:0] IR;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      A <= 'x;
      X <= 'x;
      Y <= 'x;
      sp <= 0;
      done <= 0;
      display_out <= 0;
      IR <= 0;
      for (int i=0; i<40; i++) stack[i] <= '0;
    end else begin
      current_state <= next_state;
      
      case (current_state)
        FETCH: IR <= input_num;
        EXECUTE: begin
          case (IR[7:5])
            3'b000: begin // PH
              if (sp < 40) begin
                case (IR[1:0])
                  2'b00: stack[sp] <= A;
                  2'b01: stack[sp] <= X;
                  2'b10: stack[sp] <= Y;
                endcase
                sp <= sp + 1;
              end
            end
            
            3'b001: begin // PL
              if (sp == 0) begin
                done <= 1;
                display_out <= 'x;
              end else begin
                sp <= sp - 1;
                case (IR[1:0])
                  2'b00: A <= stack[sp-1];
                  2'b01: X <= stack[sp-1];
                  2'b10: Y <= stack[sp-1];
                endcase
              end
            end
            
            3'b010: begin // AD
              if (sp >= 2) begin
                stack[sp-2] <= stack[sp-1] + stack[sp-2];
                sp <= sp - 1;
              end else begin
                done <= 1;
              end
            end
            
            3'b011: begin // ZE
              A <= input_num;
              X <= input_num;
            end
            
            3'b100: begin // ST
              if (input_num[0]) Y <= A;
              else X <= A;
            end
            
            3'b101: begin // DI
              done <= 1;
              case (IR[1:0])
                2'b00: display_out <= A;
                2'b01: display_out <= X;
                2'b10: display_out <= Y;
                default: display_out <= 'x;
              endcase
            end
          endcase
        end
        
        DONE: done <= 1;
      endcase
    end
  end
  
  always_comb begin
    next_state = current_state;
    
    case (current_state)
      IDLE: next_state = start ? FETCH : IDLE;
      FETCH: next_state = EXECUTE;
      EXECUTE: begin
        if ((IR[7:5] == 3'b101) || (IR[7:5] == 3'b001 && sp == 0))
          next_state = DONE;
        else
          next_state = FETCH;
      end
      DONE: next_state = DONE;
    endcase
  end
endmodule