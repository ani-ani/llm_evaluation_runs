module odd_collatz (
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  output reg done,
  output reg [9:0] odd_mem [0:15],
  output reg [4:0] count
);

  // States
  enum {IDLE, COMPUTE, FINAL_STORE, DONE} state;
  
  // Working registers
  reg [9:0] current;
  reg [6:0] cycles;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      count <= 5'b0;
      current <= 10'b0;
      cycles <= 7'b0;
      for (int i=0; i<16; i++) odd_mem[i] <= 10'b0;
    end else begin
      case (state)        
        IDLE: begin
          if (start) begin
            state <= COMPUTE;
            current <= n;
            count <= 0;
            cycles <= 0;
            done <= 0;
          end
        end
        
        COMPUTE: begin
          cycles <= cycles + 1;
          
          if (current == 1) begin
            state <= FINAL_STORE;
          end else if (cycles == 127) begin
            state <= DONE;  // Timeout after 128 cycles (0-127)
          end else begin
            if (current[0]) begin  // Odd
              if (count < 16) begin
                odd_mem[count] <= current;
                count <= count + 1;
              end
              current <= (current << 1) + current + 1;  // 3n+1
            end else begin          // Even
              current <= current >> 1;  // n/2
            end
          end
        end

        FINAL_STORE: begin
          if (current == 1 && count < 16) begin
            odd_mem[count] <= 10'd1;
            count <= count + 1;
          end
          state <= DONE;
        end
        
        DONE: begin
          done <= 1'b1;
          if (start) begin
            state <= COMPUTE;
            current <= n;
            count <= 0;
            cycles <= 0;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule