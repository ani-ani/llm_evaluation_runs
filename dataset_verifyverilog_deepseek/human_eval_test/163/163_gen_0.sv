module even_digit_filter (
  input clk,
  input rst_n,
  input start,
  input [7:0] a,
  input [7:0] b,
  output reg [3:0][7:0] result_array,
  output reg [1:0] valid_count,
  output reg done
);
  
  typedef enum logic [1:0] { 
    IDLE,
    CALC_MIN_MAX,
    ITERATING,
    DONE
  } state_t;
  
  state_t state;
  reg [7:0] min_val_reg, max_val_reg;
  reg [7:0] current_val;
  reg [1:0] stored_count;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      valid_count <= 0;
      result_array <= 'h0;
      stored_count <= 0;
      current_val <= 0;
      min_val_reg <= 0;
      max_val_reg <= 0;
    end else begin
      done <= 0;  
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALC_MIN_MAX;
            stored_count <= 0;
          end
        end
        
        CALC_MIN_MAX: begin
          min_val_reg <= (a < b) ? a : b;
          max_val_reg <= (a > b) ? a : b;
          current_val <= (a < b) ? a : b;
          state <= ITERATING;
        end
        
        ITERATING: begin
          if (current_val <= max_val_reg) begin
            if ((current_val <= 8'd9) && (current_val[0] == 1'b0)) begin
              if (stored_count < 2'd3) begin
                result_array[stored_count] <= current_val;
                stored_count <= stored_count + 1;
              end
            end
            current_val <= current_val + 1;
          end else begin
            state <= DONE;
          end
        end
        
        DONE: begin
          valid_count <= stored_count;
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule