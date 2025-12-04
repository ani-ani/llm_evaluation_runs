module last_position (
  input clk,
  input rst_n,
  input start,
  input [7:0] target,
  input [7:0] [7:0] arr,
  output reg [2:0] position,
  output reg found,
  output reg done
);

  localparam IDLE = 2'b00;
  localparam SEARCH = 2'b01;
  localparam DONE = 2'b10;
  
  reg [1:0] state;
  reg [2:0] low;
  reg [2:0] high;
  wire [2:0] mid;
  
  assign mid = (low + high) >> 1;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      found <= 1'b0;
      position <= 3'b0;
      low <= 3'b0;
      high <= 3'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= SEARCH;
            low <= 3'd0;
            high <= 3'd7;
            done <= 1'b0;
          end
        end
        
        SEARCH: begin
          if (low <= high) begin
            if (arr[mid] <= target) begin
              low <= mid + 1'b1;
            end else begin
              high <= mid - 1'b1;
            end
            state <= SEARCH;
          end else begin
            state <= DONE;
          end
        end
        
        DONE: begin
          if (low != 3'd0 && arr[low - 1] == target) begin
            found <= 1'b1;
            position <= low - 1'b1;
          end else begin
            found <= 1'b0;
            position <= 3'd0;
          end
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
  
endmodule