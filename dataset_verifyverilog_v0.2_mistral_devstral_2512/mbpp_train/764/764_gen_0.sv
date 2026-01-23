module digit_counter (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  output reg [4:0] addr_out,
  output reg [4:0] count,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    READ_CHAR,
    CHECK,
    UPDATE,
    FINISH
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [4:0] addr_reg;
  reg [4:0] count_reg;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      addr_reg <= 0;
      count_reg <= 0;
      addr_out <= 0;
      count <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
      
      case (current_state)
        IDLE: begin
          if (start) begin
            addr_reg <= 0;
            count_reg <= 0;
            addr_out <= 0;
            count <= 0;
            done <= 0;
          end
        end
        
        READ_CHAR: begin
          addr_out <= addr_reg;
        end
        
        CHECK: begin
          if (char_in >= 8'h30 && char_in <= 8'h39) begin
            count_reg <= count_reg + 1;
          end
        end
        
        UPDATE: begin
          addr_reg <= addr_reg + 1;
          count <= count_reg;
        end
        
        FINISH: begin
          done <= 1;
        end
        
        default: begin
          current_state <= IDLE;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = READ_CHAR;
        end
      end
      
      READ_CHAR: begin
        next_state = CHECK;
      end
      
      CHECK: begin
        next_state = UPDATE;
      end
      
      UPDATE: begin
        if (addr_reg == 15) begin
          next_state = FINISH;
        end else begin
          next_state = READ_CHAR;
        end
      end
      
      FINISH: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
      
      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule