module consecutive_checker (
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] array_in,
  output reg consecutive,
  output reg done
);
  typedef enum logic [1:0] { IDLE = 2'b00, SORT = 2'b01, CHECK = 2'b10, DONE = 2'b11 } state_t;
  
  reg [7:0][7:0] signed sorted_array;
  reg [6:0] cycle_counter;
  state_t state;
  
  logic signed [7:0] min_val, max_val;
  logic cond1, cond2, cond3;
  integer i;
  
  always_comb begin
    min_val = sorted_array[0];
    max_val = sorted_array[7];
    cond1 = ((max_val - min_val + 1) == 8'd8);
    cond2 = 1'b1;
    for (i=1; i<8; i++) begin
      if (sorted_array[i] == sorted_array[i-1])
        cond2 = 1'b0;
    end
    cond3 = 1'b1;
    for (i=1; i<8; i++) begin
      if ((sorted_array[i] - sorted_array[i-1]) != 1)
        cond3 = 1'b0;
    end
  end
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      consecutive <= 1'b0;
      done <= 1'b1;
      sorted_array <= '{default:0};
      cycle_counter <= 7'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b1;
          consecutive <= 1'b0;
          if (start) begin
            state <= SORT;
            done <= 1'b0;
            sorted_array <= array_in;
            cycle_counter <= 7'b0;
          end
        end
        
        SORT: begin
          if (cycle_counter < 7'd64) begin
            if (cycle_counter[2:0] < 3'd7) begin
              if (sorted_array[cycle_counter[2:0]] > sorted_array[cycle_counter[2:0] + 1]) begin
                sorted_array[cycle_counter[2:0]] <= sorted_array[cycle_counter[2:0] + 1];
                sorted_array[cycle_counter[2:0] + 1] <= sorted_array[cycle_counter[2:0]];
              end
            end
            cycle_counter <= cycle_counter + 1;
          end else begin
            state <= CHECK;
          end
        end
        
        CHECK: begin
          consecutive <= cond1 && cond2 && cond3;
          state <= DONE;
        end
        
        DONE: begin
          done <= 1'b1;
          if (!start)
            state <= IDLE;
        end
      endcase
    end
  end
endmodule