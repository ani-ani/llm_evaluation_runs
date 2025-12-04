module max_non_square(
  input clk,
  input rst_n,
  input start,
  input signed [15:0] arr [0:7],
  output reg signed [15:0] result,
  output reg done
);

  // FSM states
  enum reg [1:0] { IDLE, COMPARE, DONE_ST } state;
  
  // Internal registers
  reg [2:0] cnt;
  reg signed [15:0] max_val;
  wire [7:0] arr_idx;
  
  // State machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      cnt <= 3'd0;
      max_val <= -16'sd32768;
      result <= 0;
      done <= 0;
    end
    else begin
      done <= 1'b0;
      case (state)
        IDLE: begin
          cnt <= 3'd0;
          max_val <= -16'sd32768;
          if (start) state <= COMPARE;
        end
        
        COMPARE: begin
          // Update max if current element is non-square
          if (is_non_square(arr[cnt]) && (arr[cnt] > max_val))
            max_val <= arr[cnt];
          
          if (cnt == 3'd7) begin
            state <= DONE_ST;
            result <= max_val;  // Update result on exit
          end
          else cnt <= cnt + 1;
        end
        
        DONE_ST: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end

  // Non-square detection function
  function automatic logic is_non_square(input signed [15:0] num);
    integer y;
    logic square_match;
    begin
      if (num < 0)
        is_non_square = 1'b1;
      else begin
        square_match = 1'b0;
        for (y = 0; y <= 181; y = y + 1) begin
          if (y*y == num)
            square_match = 1'b1;
        end
        is_non_square = ~square_match;
      end
    end
  endfunction

endmodule