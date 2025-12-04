module diophantine_solver(
  input clk,
  input rst_n,
  input start,
  input [7:0] a,
  input [7:0] b,
  input [7:0] n,
  output reg [7:0] x,
  output reg [7:0] y,
  output reg done,
  output reg no_sol
);

  reg [7:0] i;            // 8-bit counter for i
  reg [15:0] current_a;   // 16-bit to hold i*a (max 255*255=65025)
  reg [1:0] state;        // state machine: 0=IDLE, 1=SEARCH, 2=DONE
  
  // State definitions
  parameter IDLE = 2'b00;
  parameter SEARCH = 2'b01;
  parameter DONE = 2'b10;
  
  // State machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 8'b0;
      current_a <= 16'b0;
      x <= 8'b0;
      y <= 8'b0;
      done <= 1'b0;
      no_sol <= 1'b0;
    end
    else begin
      case (state)
        IDLE: begin
          if (start) begin
            // Initialize for new computation
            state <= SEARCH;
            i <= 8'b0;
            current_a <= 16'b0;
            x <= 8'b0;
            y <= 8'b0;
            done <= 1'b0;
            no_sol <= 1'b0;
          end
        end
        
        SEARCH: begin
          if (current_a <= n) begin
            // Check if (n - i*a) is divisible by b
            if ((n - current_a[7:0]) % b == 0) begin
              // Solution found
              x <= i;
              y <= (n - current_a[7:0]) / b;
              no_sol <= 1'b0;
              state <= DONE;
            end
            else begin
              // Increment i and update current_a
              i <= i + 1;
              current_a <= current_a + a;  // Add a to current_a
            end
          end
          else begin
            // i*a > n, no solution exists
            no_sol <= 1'b1;
            state <= DONE;
          end
        end
        
        DONE: begin
          // Pulse done high for one cycle
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule