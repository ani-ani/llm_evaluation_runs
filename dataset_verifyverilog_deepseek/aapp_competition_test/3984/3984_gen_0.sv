module string_game_winner(
  input clk,
  input rst_n,
  input start,
  input [3:0] str_len,
  input [7:0] char_in,
  output reg [15:0] results,
  output reg done
);
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] PROCESSING = 2'b01;
  localparam [1:0] DONE = 2'b10;
  
  reg [1:0] state;
  reg [3:0] counter;
  reg [3:0] str_len_reg;
  reg [7:0] running_min;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      counter <= 4'b0;
      str_len_reg <= 4'b0;
      running_min <= 8'b0;
      results <= 16'b0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            str_len_reg <= str_len;
            running_min <= 8'd122;
            counter <= 4'b0;
            results <= 16'b0;
            if (str_len == 4'b0) begin
              state <= DONE;
              done <= 1'b1;
            end else begin
              state <= PROCESSING;
            end
          end
        end
        
        PROCESSING: begin
          if (counter == 4'd0) begin
            results[counter] <= 1'b0;
          end else begin
            results[counter] <= (char_in > running_min);
          end
          
          if (char_in < running_min) begin
            running_min <= char_in;
          end
          
          counter <= counter + 1;
          
          if (counter + 1 == str_len_reg) begin
            state <= DONE;
            done <= 1'b1;
          end
        end
        
        DONE: begin
          // No actions - hold state until reset
        end
      endcase
    end
  end
endmodule