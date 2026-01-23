module fizz_buzz(
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  output reg [7:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CHECK_DIVISIBILITY,
    COUNT_SEVENS,
    INCREMENT,
    DONE
  } state_t;

  state_t state;
  reg [7:0] i;
  reg [7:0] count;

  // Divisibility check
  function automatic logic is_divisible(input [7:0] num);
    return (num % 11 == 0) || (num % 13 == 0);
  endfunction

  // Count 7s in decimal representation
  function automatic [7:0] count_sevens(input [7:0] num);
    reg [7:0] cnt = 0;
    reg [7:0] digit;
    
    digit = num % 10;
    if (digit == 7) cnt++;
    
    digit = (num / 10) % 10;
    if (digit == 7) cnt++;
    
    digit = num / 100;
    if (digit == 7) cnt++;
    
    return cnt;
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 0;
      result <= 0;
      done <= 0;
      count <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CHECK_DIVISIBILITY;
            i <= 0;
            result <= 0;
            done <= 0;
          end
        end
        
        CHECK_DIVISIBILITY: begin
          if (i < n) begin
            if (is_divisible(i)) begin
              state <= COUNT_SEVENS;
            end else begin
              state <= INCREMENT;
            end
          end else begin
            state <= DONE;
          end
        end
        
        COUNT_SEVENS: begin
          count = count_sevens(i);
          result <= result + count;
          state <= INCREMENT;
        end
        
        INCREMENT: begin
          i <= i + 1;
          state <= CHECK_DIVISIBILITY;
        end
        
        DONE: begin
          done <= 1;
          if (start) begin
            state <= CHECK_DIVISIBILITY;
            i <= 0;
            result <= 0;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule