module attendance_min_time(
  input clk,
  input rst_n,
  input start,
  input [2:0] m,
  input [2:0] n,
  input [2:0] a [0:7],
  input [2:0] b [0:7],
  output reg [7:0] k,
  output reg done
);
  typedef enum logic [1:0] {IDLE, LOAD, PROCESS, DONE} state_t;
  reg [2:0] a_reg [0:7];
  reg [2:0] queue_storage [0:7];
  reg [2:0] head;
  reg [2:0] tail;
  reg [3:0] queue_count;
  reg [2:0] list_ptr;
  state_t state;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      k <= 8'b0;
      foreach (a_reg[i]) a_reg[i] <= 3'b0;
      foreach (queue_storage[i]) queue_storage[i] <= 3'b0;
      head <= 0;
      tail <= 0;
      queue_count <= 0;
      list_ptr <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= LOAD;
            k <= 0;
          end
        end
        
        LOAD: begin
          a_reg <= a;
          foreach (queue_storage[i]) begin
            if (i < n) queue_storage[i] <= b[i];
            else queue_storage[i] <= 3'b0;
          end
          head <= 0;
          tail <= n;
          queue_count <= n;
          list_ptr <= 0;
          state <= PROCESS;
        end
        
        PROCESS: begin
          if (list_ptr < m) begin
            if (queue_count > 0) begin
              if (a_reg[list_ptr] == queue_storage[head]) begin
                list_ptr <= list_ptr + 1;
                head <= (head + 1) % 8;
                queue_count <= queue_count - 1;
              end else begin
                queue_storage[tail] <= queue_storage[head];
                head <= (head + 1) % 8;
                tail <= (tail + 1) % 8;
              end
              k <= k + 1;
            end else begin
              state <= DONE;
            end
          end else begin
            state <= DONE;
          end
        end
        
        DONE: begin
          done <= 1;
          if (start) state <= LOAD;
          else state <= DONE;
        end
      endcase
    end
  end
endmodule