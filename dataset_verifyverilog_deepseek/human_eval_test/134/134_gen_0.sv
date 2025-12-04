module last_char_checker(input clk, input rst_n, input start, input [15:0][7:0] txt, output reg result, output reg done);
  reg [3:0] counter;
  reg [1:0] state;
  reg prev_was_space;
  reg last_valid_exists;
  reg last_char_is_letter;
  reg last_valid_prev_was_space;
  
  localparam IDLE = 2'd0;
  localparam PROCESSING = 2'd1;
  localparam DONE = 2'd2;
  
  wire [7:0] current_char = txt[counter];
  wire is_zero = (current_char == 8'h00);
  wire is_space = (current_char == 8'h20);
  wire is_letter = ((current_char >= 8'h41 && current_char <= 8'h5A) || (current_char >= 8'h61 && current_char <= 8'h7A));
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b1;
      result <= 1'b0;
      counter <= 4'b0;
      state <= IDLE;
      prev_was_space <= 1'b1;
      last_valid_exists <= 1'b0;
      last_char_is_letter <= 1'b0;
      last_valid_prev_was_space <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            done <= 1'b0;
            result <= 1'b0;
            counter <= 4'b0;
            prev_was_space <= 1'b1;
            last_valid_exists <= 1'b0;
            state <= PROCESSING;
          end
        end
        PROCESSING: begin
          if (!is_zero && !is_space) begin
            last_valid_exists <= 1'b1;
            last_char_is_letter <= is_letter;
            last_valid_prev_was_space <= prev_was_space;
            prev_was_space <= 1'b0;
          end else if (is_space) begin
            prev_was_space <= 1'b1;
          end
          
          if (counter == 4'd15) begin
            state <= DONE;
          end else begin
            counter <= counter + 1;
          end
        end
        DONE: begin
          done <= 1'b1;
          result <= last_valid_exists && last_char_is_letter && last_valid_prev_was_space;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule