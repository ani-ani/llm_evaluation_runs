module coin_payer (
  input clk,
  input rst_n,
  input start,
  input [7:0] P,
  input [3:0] N1,
  input [3:0] N5,
  input [3:0] N10,
  input [3:0] N25,
  output reg [5:0] coins_used,
  output reg impossible,
  output reg done
);

  localparam IDLE = 0, CALC_25 = 1, CALC_10 = 2, CALC_5 = 3, CALC_1 = 4;
  
  logic [2:0] current_state, next_state;
  logic [7:0] remaining, N1_reg, N5_reg, N10_reg, N25_reg;
  logic [5:0] coins_used_reg;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      coins_used <= 0;
      impossible <= 0;
      done <= 0;
      remaining <= 0;
      N1_reg <= 0;
      N5_reg <= 0;
      N10_reg <= 0;
      N25_reg <= 0;
      coins_used_reg <= 0;
    end else begin
      current_state <= next_state;
      
      case (current_state)
        IDLE: begin
          if (start) begin
            remaining <= P;
            N1_reg <= N1;
            N5_reg <= N5;
            N10_reg <= N10;
            N25_reg <= N25;
            coins_used_reg <= 0;
            next_state <= CALC_25;
          end else begin
            next_state <= IDLE;
          end
          coins_used <= 0;
          impossible <= 0;
          done <= 0;
        end
        
        CALC_25: begin
          logic [7:0] c25_temp;
          c25_temp = (N25_reg > (remaining / 25)) ? (remaining / 25) : N25_reg;
          coins_used_reg <= coins_used_reg + c25_temp;
          remaining <= remaining - c25_temp * 25;
          N25_reg <= 0;
          coins_used <= 0;
          impossible <= 0;
          done <= 0;
          next_state <= CALC_10;
        end
        
        CALC_10: begin
          logic [7:0] c10_temp;
          c10_temp = (N10_reg > (remaining / 10)) ? (remaining / 10) : N10_reg;
          coins_used_reg <= coins_used_reg + c10_temp;
          remaining <= remaining - c10_temp * 10;
          N10_reg <= 0;
          coins_used <= 0;
          impossible <= 0;
          done <= 0;
          next_state <= CALC_5;
        end
        
        CALC_5: begin
          logic [7:0] c5_temp;
          c5_temp = (N5_reg > (remaining / 5)) ? (remaining / 5) : N5_reg;
          coins_used_reg <= coins_used_reg + c5_temp;
          remaining <= remaining - c5_temp * 5;
          N5_reg <= 0;
          coins_used <= 0;
          impossible <= 0;
          done <= 0;
          next_state <= CALC_1;
        end
        
        CALC_1: begin
          logic [5:0] total_coins;
          if (remaining <= N1_reg) begin
            total_coins = coins_used_reg + remaining;
            coins_used_reg <= total_coins;
            remaining <= 0;
            coins_used <= total_coins;
            impossible <= 0;
            done <= 1;
          end else begin
            coins_used <= 0;
            impossible <= 1;
            done <= 1;
          end
          next_state <= IDLE;
        end
        
        default: begin
          next_state <= IDLE;
          coins_used <= 0;
          impossible <= 0;
          done <= 0;
        end
      endcase
    end
  end

endmodule