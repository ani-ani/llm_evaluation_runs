module attendance_min_time(
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0] m,
  input  [2:0] n,
  input  [2:0] a [0:7],
  input  [2:0] b [0:7],
  output reg [7:0] k,
  output reg done
);

  // State encoding
  localparam IDLE    = 2'b00;
  localparam LOAD    = 2'b01;
  localparam PROCESS = 2'b10;
  localparam DONE    = 2'b11;

  reg [1:0] state, next_state;

  // Internal storage for list a and queue b (circular buffer)
  reg [2:0] a_mem [0:7];
  reg [2:0] q_mem [0:7];

  // List index
  reg [2:0] idx_list;

  // Queue management
  reg [2:0] head;     // points to current front
  reg [2:0] tail;     // points to next write position (one past last element)
  reg [2:0] q_count;  // current number of elements in queue (0..8)

  // Control registers
  reg start_d;        // registered start to detect rising edge

  // Rising edge detection for start
  wire start_pulse = start & ~start_d;

  integer i;

  // Sequential block: state, registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      k         <= 8'd0;
      done      <= 1'b0;
      idx_list  <= 3'd0;
      head      <= 3'd0;
      tail      <= 3'd0;
      q_count   <= 3'd0;
      start_d   <= 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        a_mem[i] <= 3'd0;
        q_mem[i] <= 3'd0;
      end
    end else begin
      // register start for edge detection
      start_d <= start;

      // State transition
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          k    <= 8'd0;
          if (start_pulse) begin
            // Load 'a' into a_mem
            for (i = 0; i < 8; i = i + 1) begin
              a_mem[i] <= a[i];
            end
            // Load 'b' into q_mem and initialize queue
            for (i = 0; i < 8; i = i + 1) begin
              q_mem[i] <= b[i];
            end
            idx_list <= 3'd0;
            head     <= 3'd0;
            tail     <= n[2:0];
            q_count  <= n[2:0];
          end
        end

        LOAD: begin
          // LOAD is a transient state; all loading already done in IDLE on start_pulse
          // Prepare for processing
          done <= 1'b0;
        end

        PROCESS: begin
          done <= 1'b0;
          // Only operate if there are list entries to match
          if (idx_list < m) begin
            // Only compare if queue is non-empty
            if (q_count != 3'd0) begin
              // Increment inspection count for each comparison
              k <= k + 8'd1;

              // Front element at head
              if (q_mem[head] == a_mem[idx_list]) begin
                // Match: remove from queue and advance list index
                head    <= (head == 3'd7) ? 3'd0 : (head + 3'd1);
                q_count <= q_count - 3'd1;
                idx_list <= idx_list + 3'd1;
              end else begin
                // No match: rotate front to end
                q_mem[tail] <= q_mem[head];
                tail        <= (tail == 3'd7) ? 3'd0 : (tail + 3'd1);
                head        <= (head == 3'd7) ? 3'd0 : (head + 3'd1);
                // q_count unchanged on rotation
              end
            end
          end
        end

        DONE: begin
          done <= 1'b1;
        end

        default: begin
          // Fallback to safe state
          state <= IDLE;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_pulse)
          next_state = LOAD;
      end

      LOAD: begin
        // Immediately proceed to PROCESS after initialization
        next_state = PROCESS;
      end

      PROCESS: begin
        // When all list entries processed, go to DONE
        if (idx_list >= m)
          next_state = DONE;
        else
          next_state = PROCESS;
      end

      DONE: begin
        // Wait for next start pulse to restart
        if (start_pulse)
          next_state = LOAD;
        else
          next_state = DONE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule