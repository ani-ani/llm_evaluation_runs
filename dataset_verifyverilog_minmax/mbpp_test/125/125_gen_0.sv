module max_zero_diff(
  input clk,
  input rst_n,
  input start,
  input [15:0] data,
  input [3:0] str_len,
  output reg [4:0] max_diff,
  output reg done
);

  reg [1:0] state;
  reg [3:0] bit_counter;
  reg signed [5:0] current_sum;
  reg [5:0] max_sum;
  
  localparam IDLE = 2'b00;
  localparam PROCESS = 2'b01;
  localparam DONE = 2'b10;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      current_sum <= 0;
      max_sum <= 0;
      bit_counter <= 0;
      max_diff <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESS;
            done <= 0;
            current_sum <= 0;
            max_sum <= 0;
            bit_counter <= 0;
          end
        end
        
        PROCESS: begin
          // Update current_sum based on current bit
          if (data[15 - bit_counter] == 1'b0) begin
            current_sum <= current_sum + 1;
          end else begin
            current_sum <= current_sum - 1;
          end
          
          // Reset current_sum if negative
          if (current_sum < 0) begin
            current_sum <= 0;
          end
          
          // Update max_sum if current_sum is greater
          if (current_sum > max_sum) begin
            max_sum <= current_sum;
          end
          
          // Check if this is the last bit
          if (bit_counter == str_len - 1) begin
            // Set output and done signal
            if (max_sum == 6'd16) begin
              max_diff <= 5'b10000; // 16
            end else begin
              max_diff <= max_sum[4:0];
            end
            done <= 1;
            state <= IDLE;
          end else begin
            // Move to next bit
            bit_counter <= bit_counter + 1;
            state <= PROCESS;
            done <= 0;
          end
        end
        
        DONE: begin
          state <= IDLE;
          done <= 0;
        end
        
        default: state <= IDLE;
      endcase
    end
  end
endmodule