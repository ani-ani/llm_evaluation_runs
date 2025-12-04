module next_palindrome(
  input clk,
  input rst_n,
  input start,
  input [15:0] num,
  output reg [15:0] palindrome,
  output reg done
);
  
  localparam [1:0] IDLE = 2'b00,
                   CHECKING = 2'b01,
                   DONE = 2'b10;
  
  reg [1:0] state, next_state;
  reg [15:0] current;
  reg [7:0] cnt;
  wire [3:0] digit0, digit1, digit2, digit3, digit4;
  wire is_pal;
  
  // BCD conversion combinational logic
  assign digit4 = current / 16'd10000;
  assign digit3 = (current % 16'd10000) / 16'd1000;
  assign digit2 = (current % 16'd1000) / 16'd100;
  assign digit1 = (current % 16'd100) / 16'd10;
  assign digit0 = current % 16'd10;
  
  // Palindrome check
  assign is_pal = (digit0 == digit4) && (digit1 == digit3);
  
  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current <= 16'b0;
      cnt <= 8'b0;
      palindrome <= 16'b0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            current <= num + 1;
            cnt <= 8'b0;
            state <= CHECKING;
          end
        end
        
        CHECKING: begin
          if (is_pal || cnt == 8'd255) begin
            palindrome <= is_pal ? current : 16'b0;
            done <= 1'b1;
            state <= DONE;
          end else begin
            current <= current + 1;
            cnt <= cnt + 1;
          end
        end
        
        DONE: begin
          done <= 1'b0;
          state <= IDLE;
        end
        
        default: state <= IDLE;
      endcase
    end
  end
endmodule