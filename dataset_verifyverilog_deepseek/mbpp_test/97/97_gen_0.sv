module frequency_counter(input clk, input rst_n, input start, input [3:0][3:0][7:0] list1, input [7:0] query_num, output reg [3:0] frequency, output reg done);
  
  typedef enum logic [1:0] { IDLE, PROCESSING, DONE } state_t;
  state_t state;
  reg [3:0] cnt;
  reg [3:0] count_mem [0:255];
  
  always_comb begin
    if (done) frequency = count_mem[query_num];
    else frequency = 4'b0;
  end
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      cnt <= 4'b0;
      for (int i=0; i<256; i++) count_mem[i] <= 4'b0;
    end
    else case (state)
      IDLE: begin
        done <= 1'b0;
        cnt <= 4'b0;
        if (start) state <= PROCESSING;
      end
      
      PROCESSING: begin
        logic [1:0] addr_i = cnt[3:2];
        logic [1:0] addr_j = cnt[1:0];
        logic [7:0] current_val = list1[addr_i][addr_j];
        
        if (cnt == 0) for (int i=0; i<256; i++) count_mem[i] <= 4'b0;
        
        if (count_mem[current_val] < 4'd15) begin
          count_mem[current_val] <= count_mem[current_val] + 1;
        end
        
        cnt <= cnt + 1;
        if (cnt == 4'd15) state <= DONE;
      end
      
      DONE: begin
        done <= 1'b1;
        if (start) state <= PROCESSING;
      end
    endcase
  end
endmodule