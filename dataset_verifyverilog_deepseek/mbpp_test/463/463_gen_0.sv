module max_product_subarray (
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] arr,
  output reg signed [15:0] max_product,
  output reg done
);
  
  typedef enum {IDLE, PROCESS, DONE_ST} state_t;
  reg [2:0] index;
  state_t state, next_state;
  reg signed [15:0] max_so_far;
  reg signed [15:0] max_end;
  reg signed [15:0] min_end;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      max_product <= 0;
      max_so_far <= 0;
      max_end <= 0;
      min_end <= 0;
      index <= 0;
    end
    else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            next_state <= PROCESS;
            state <= next_state;
            index <= 0;
          end
        end
        PROCESS: begin
          if (index == 0) begin
            max_end <= $signed({{8{arr[0][7]}}, arr[0]});
            min_end <= $signed({{8{arr[0][7]}}, arr[0]});
            max_so_far <= $signed({{8{arr[0][7]}}, arr[0]});
            index <= index + 1;
          end
          else begin
            reg signed [15:0] current;
            current = $signed({{8{arr[index][7]}}, arr[index]});
            
            reg signed [15:0] prod_max, prod_min;
            reg signed [15:0] temp_max, temp_min;
            
            prod_max = current * max_end;
            prod_min = current * min_end;
            
            temp_max = (current > prod_max) ? current : prod_max;
            temp_max = (temp_max > prod_min) ? temp_max : prod_min;
            
            temp_min = (current < prod_max) ? current : prod_max;
            temp_min = (temp_min < prod_min) ? temp_min : prod_min;
            
            max_so_far <= (temp_max > max_so_far) ? temp_max : max_so_far;
            
            if (current == 0) begin
              max_end <= 1;
              min_end <= 1;
            end
            else begin
              max_end <= temp_max;
              min_end <= temp_min;
            end
            
            index <= index + 1;
          end
          
          if (index == 3'b111) begin
            next_state <= DONE_ST;
            state <= next_state;
          end
          else if (index != 0) begin
            next_state <= PROCESS;
            state <= next_state;
          end
        end
        DONE_ST: begin
          max_product <= max_so_far;
          done <= 1;
          next_state <= IDLE;
          state <= next_state;
        end
      endcase
    end
  end
endmodule