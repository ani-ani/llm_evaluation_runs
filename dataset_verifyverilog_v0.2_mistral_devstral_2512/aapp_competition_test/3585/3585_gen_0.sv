module bag_capacity (
  input clk,
  input rst_n,
  input start,
  input [7:0] m,
  input [3:0] k,
  output reg [31:0] result,
  output reg done
);

  // Constants
  localparam MODULUS = 998244353;
  localparam IDLE = 2'b00;
  localparam CALC_BASE = 2'b01;
  localparam MULTIPLY = 2'b10;
  localparam DONE = 2'b11;

  // State register
  reg [1:0] state, next_state;

  // Intermediate registers
  reg [31:0] base;
  reg [31:0] temp_result;
  reg [3:0] counter;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      done <= 0;
      base <= 0;
      temp_result <= 0;
      counter <= 0;
    end else begin
      state <= next_state;
      
      case (state)
        IDLE: begin
          if (start) begin
            next_state <= CALC_BASE;
          end else begin
            next_state <= IDLE;
          end
        end
        
        CALC_BASE: begin
          base <= (2 * m + 1);
          temp_result <= base;
          counter <= k - 1;
          next_state <= MULTIPLY;
        end
        
        MULTIPLY: begin
          if (counter > 0) begin
            temp_result <= (temp_result * base) % MODULUS;
            counter <= counter - 1;
            next_state <= MULTIPLY;
          end else begin
            result <= temp_result;
            next_state <= DONE;
          end
        end
        
        DONE: begin
          done <= 1;
          if (!start) begin
            done <= 0;
            next_state <= IDLE;
          end else begin
            next_state <= DONE;
          end
        end
      endcase
    end
  end

endmodule