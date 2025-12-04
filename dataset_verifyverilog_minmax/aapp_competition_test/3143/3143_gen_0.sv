module attendance_min_time (
  input clk,
  input rst_n,
  input start,
  input [2:0] m,
  input [2:0] n,
  input [2:3] a,
  input [2:3] b,
  output reg [7:0] k,
  output reg done
);

  // Internal memories and state
  reg [2:0] list_mem [0:7];
  reg [2:0] queue_mem [0:7];
  reg [2:0] head, tail;
  reg [2:0] queue_cnt;
  reg [2:0] list_head;
  reg [2:0] list_processed;
  reg [1:0] state, next_state;

  // States
  localparam IDLE  = 2'b00;
  localparam LOAD  = 2'b01;
  localparam PROCESS = 2'b10;
  localparam DONE  = 2'b11;

  // Sequential logic with active-low reset
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      k <= 8'h0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      k <= k;
      done <= done;
    end
  end

  // State machine and datapath
  always @(*) begin
    // Defaults (avoid latches)
    next_state = state;
    k = k;
    done = 1'b0;

    case (state)
      IDLE: begin
        k = 8'h0;
        done = 1'b0;
        if (start) begin
          next_state = LOAD;
        end else begin
          next_state = IDLE;
        end
      end

      LOAD: begin
        // Load 'a' and 'b' into internal memories
        list_mem[0] = a;
        list_mem[1] = a;
        list_mem[2] = a;
        list_mem[3] = a;
        list_mem[4] = a;
        list_mem[5] = a;
        list_mem[6] = a;
        list_mem[7] = a;

        queue_mem[0] = b;
        queue_mem[1] = b;
        queue_mem[2] = b;
        queue_mem[3] = b;
        queue_mem[4] = b;
        queue_mem[5] = b;
        queue_mem[6] = b;
        queue_mem[7] = b;

        // Initialize pointers and counters
        head = 3'b0;
        tail = n;        // one-past-last position after filling
        queue_cnt = n;
        list_head = 3'b0; // first list entry
        list_processed = 3'b0;

        next_state = (m == 3'b0) ? DONE : PROCESS;
      end

      PROCESS: begin
        // One comparison per cycle
        k = k + 1;
        list_processed = list_processed + 1;

        if (list_processed >= m) begin
          // All list entries processed (comparison performed for last one)
          next_state = DONE;
        end else begin
          // More entries to process
          list_head = list_head + 1;
          next_state = PROCESS;
        end

        // Perform the queue operation based on comparison result
        if (queue_mem[head] == list_mem[list_head]) begin
          // Match: remove from both queue and list (dequeue only)
          head = head + 1;
          queue_cnt = queue_cnt - 1;
        end else begin
          // No match: move front student to queue end (rotate)
          queue_mem[tail] = queue_mem[head];
          head = head + 1;
          tail = tail + 1;
          // queue_cnt unchanged
        end
      end

      DONE: begin
        done = 1'b1;
        k = k; // hold final count
        if (start) begin
          // Restart if start is held/asserted
          next_state = LOAD;
        end else begin
          next_state = DONE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule
