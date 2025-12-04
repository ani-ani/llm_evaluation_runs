module digit_product_solver(
  input clk,
  input rst_n,
  input start,
  input [3:0] B,
  input [15:0] N,
  output reg [31:0] X,
  output reg impossible,
  output reg done
);
  
  reg [15:0] remaining;
  reg [3:0] convert_d;
  reg [31:0] temp_X;
  reg [4:0] state;
  reg [4:0] counts [15:0];
  
  parameter S_IDLE    = 3'h0;
  parameter S_FACTOR  = 3'h1;
  parameter S_CONVERT = 3'h2;
  parameter S_DONE    = 3'h3;
  parameter S_IMPOS   = 3'h4;
  
  logic [3:0] d_found;
  
  always_comb begin : find_divisor
    d_found = 4'h0;
    for (int i = 15; i >= 2; i--) begin
      if ((i <= (B - 1)) && (remaining != 0) && ((remaining % i) == 0)) begin
        d_found = i;
        break;
      end
    end
  end
  
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= S_IDLE;
      done <= 1'b0;
      impossible <= 1'b0;
      X <= 32'h0;
      temp_X <= 32'h0;
      remaining <= 16'h0;
      convert_d <= 4'h0;
      for (int j = 0; j < 16; j++) counts[j] <= 5'h0;
    end else begin
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          impossible <= 1'b0;
          X <= 32'h0;
          temp_X <= 32'h0;
          if (start) begin
            state <= S_FACTOR;
            remaining <= N;
            for (int j = 0; j < 16; j++) counts[j] <= 5'h0;
          end
        end
        
        S_FACTOR: begin
          if (d_found != 0) begin
            counts[d_found] <= counts[d_found] + 1;
            remaining <= remaining / d_found;
          end else begin
            if (remaining == 1) begin
              state <= S_CONVERT;
              temp_X <= 32'h0;
              convert_d <= 4'h2;
            end else begin
              state <= S_IMPOS;
            end
          end
        end
        
        S_CONVERT: begin
          if (convert_d <= (B - 1)) begin
            if (counts[convert_d] != 0) begin
              temp_X <= temp_X * B + convert_d;
              counts[convert_d] <= counts[convert_d] - 1;
            end else begin
              convert_d <= convert_d + 1;
            end
          end else begin
            X <= temp_X;
            done <= 1'b1;
            state <= S_DONE;
          end
        end
        
        S_IMPOS: begin
          impossible <= 1'b1;
          done <= 1'b1;
          state <= S_DONE;
        end
        
        S_DONE: begin
          if (~start) state <= S_IDLE;
        end
      endcase
    end
  end
endmodule