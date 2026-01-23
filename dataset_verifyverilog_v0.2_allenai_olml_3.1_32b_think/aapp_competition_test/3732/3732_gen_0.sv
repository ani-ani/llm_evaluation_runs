module m_perfect_solver(input clk, input rst_n, input start, input [31:0] x_in, input [31:0] y_in, input [31:0] m_in, output reg [31:0] result, output reg done); 

reg [31:0] current_x, current_y; 
reg [31:0] result_reg; 
reg [31:0] int_count; 
reg [2:0] state; 

localparam IDLE = 3'd0, CHECK_INIT = 3'd1, NEGATIVE_FIX = 3'd2, COMPUTE_LOOP = 3'd3, DONE = 3'd4; 

always_ff @(posedge clk) begin 
  if (!rst_n) begin 
    current_x <= 32'd0; 
    current_y <= 32'd0; 
    result_reg <= 32'd0; 
    int_count <= 32'd0; 
    state <= IDLE; 
    done <= 1'b0; 
  end else begin 
    case(state) 
      IDLE: begin 
        if (start) state <= CHECK_INIT; 
        else state <= IDLE; 
      end 
      CHECK_INIT: begin 
        if (x_in >= m_in || y_in >= m_in) begin 
          result_reg <= 32'd0; 
          done <= 1'b1; 
          state <= DONE; 
        end else if ((x_in <= 32'd0) && (y_in <= 32'd0) && (m_in > 32'd0)) begin 
          result_reg <= -1; 
          done <= 1'b1; 
          state <= DONE; 
        end else begin 
          if ((x_in < 32'd0) ^ (y_in < 32'd0)) begin 
            current_x <= x_in; 
            current_y <= y_in; 
            state <= NEGATIVE_FIX; 
          end else begin 
            current_x <= x_in; 
            current_y <= y_in; 
            int_count <= 32'd0; 
            state <= COMPUTE_LOOP; 
          end 
        end 
      end 
      NEGATIVE_FIX: begin 
        if (current_x < 32'd0 && current_y > 32'd0) begin 
          integer a = -current_x; 
          integer b = current_y; 
          integer k = (a + b - 1) / b; 
          result_reg = result_reg + k; 
          current_x = current_x + (k * current_y); 
          state <= COMPUTE_LOOP; 
        end else if (current_x > 32'd0 && current_y < 32'd0) begin 
          integer a = -current_y; 
          integer b = current_x; 
          integer k = (a + b - 1) / b; 
          result_reg = result_reg + k; 
          current_y = current_y + (k * current_x); 
          state <= COMPUTE_LOOP; 
        end else begin 
          state <= COMPUTE_LOOP; 
        end 
      end 
      COMPUTE_LOOP: begin 
        if (int_count >= 50) begin 
          result_reg <= -1; 
          done <= 1'b1; 
          state <= DONE; 
        end else begin 
          if (current_x > current_y) begin 
            // Swap logic via comparison 
          end 
          if (current_y >= m_in) begin 
            done <= 1'b1; 
            state <= DONE; 
          end else begin 
            if (current_y <= 32'd0 && m_in > 32'd0) begin 
              result_reg <= -1; 
              done <= 1'b1; 
              state <= DONE; 
            end else begin 
              current_y <= current_x + current_y; 
              current_x <= current_y; 
              int_count <= int_count + 1; 
              result_reg <= result_reg + 1; 
              state <= COMPUTE_LOOP; 
            end 
          end 
        end 
      end 
      DONE: state <= DONE; 
    endcase 
  end 
endmodule 

assign result = result_reg; 
assign done = done; 
