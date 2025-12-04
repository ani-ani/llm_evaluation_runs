module min_coke_mixer(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // pulse high to start
  input [9:0] target_n, // desired concentration [0-1000]
  input [3:0] k, // number of Coke types (1-16)
  input [9:0] concentrations [0:15], // up to 16 Coke types
  output reg [6:0] min_liters, // result (0-127 or 7'b1111111 for -1)
  output reg done // high when complete
);
  // Internal types
  logic signed [7:0] base_diff [0:15];
  logic signed [7:0] queue_val [0:127];
  logic [6:0] queue_steps [0:127];
  logic [255:0] visited; // bit i corresponds to deviation (i-128)
  logic [6:0] head, tail; // circular queue pointers
  logic [6:0] steps_cur;
  logic signed [7:0] cur_dev, new_dev;
  logic [3:0] i, j; // loop indices
  logic next_tail_plus_one; // computed as (tail + 1) & 7'b1111111
  logic signed [7:0] new_dev_q; // temporary to avoid reassignment of wire
  logic enqueue_flag;
  logic zero_seen_flag;
  logic [5:0] bfs_count; // up to 128*16=2048 cycles; but we use per-cycle counter for safety

  // State machine
  typedef enum logic [1:0] {S_IDLE = 2'd0, S_INIT = 2'd1, S_BFS = 2'd2, S_DONE = 2'd3} state_t;
  state_t state, state_next;

  // Compute (tail+1) with wraparound
  assign next_tail_plus_one = (tail + 7'd1) & 7'b1111111;

  // State update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
    end else begin
      state <= state_next;
    end
  end

  // Combinational next-state logic and datapath control
  always_comb begin
    state_next = state;
    done = 1'b0;
    min_liters = 7'd0; // don't-care in non-Done
    enqueue_flag = 1'b0;
    zero_seen_flag = 1'b0;
    bfs_count = 6'd0; // loop counter to guarantee bounded runtime
    case (state)
      S_IDLE: begin
        if (start) begin
          state_next = S_INIT;
        end else begin
          state_next = S_IDLE;
        end
      end

      S_INIT: begin
        // Compute base_diffs clamped to [-127,127] and test immediate 0 solution
        zero_seen_flag = 1'b0;
        enqueue_flag = 1'b0; // will set within this block if enqueuing
        // Initialize pointers to empty queue
        head = 7'd0;
        tail = 7'd0;
        steps_cur = 7'd0;

        // Compute base_diffs and detect zero
        for (i = 4'd0; i < 4'd16; i = i + 4'd1) begin
          if (i < k) begin
            if (concentrations[i] >= target_n) begin
              base_diff[i] = (concentrations[i] - target_n) > 10'd127 ? 8'd127 : (concentrations[i] - target_n);
            end else begin
              base_diff[i] = -((target_n - concentrations[i]) > 10'd127 ? 8'd127 : (target_n - concentrations[i]));
            end
          end else begin
            base_diff[i] = 8'd0;
          end
        end

        // Check for any base_diff == 0 (1 step to 0)
        for (j = 4'd0; j < 4'd16; j = j + 4'd1) begin
          if (j < k) begin
            if (base_diff[j] == 8'd0) begin
              zero_seen_flag = 1'b1;
            end
          end
        end

        // Prepare visited vector: only mark index 128 (deviation 0) as visited for start state
        visited = 256'b0;
        visited[128] = 1'b1;

        // If found base_diff == 0, directly set steps_cur to 1 and go to DONE
        if (zero_seen_flag) begin
          steps_cur = 7'd1;
          state_next = S_DONE;
        end else begin
          // Enqueue the starting state (deviation 0, steps 0) if queue has room
          if (next_tail_plus_one != head) begin
            queue_val[tail] = 8'd0;
            queue_steps[tail] = 7'd0;
            enqueue_flag = 1'b1;
            tail = next_tail_plus_one;
          end
          state_next = S_BFS;
        end
      end

      S_BFS: begin
        bfs_count = 6'd0; // counter per visit attempt
        if (head == tail) begin
          // Queue empty -> no solution within bounded range
          state_next = S_DONE;
          done = 1'b1;
          min_liters = 7'd127; // -1 encoded
        end else begin
          // Dequeue current state
          cur_dev = queue_val[head];
          steps_cur = queue_steps[head];
          head = (head + 7'd1) & 7'b1111111;

          // Attempt to add all base_diffs as neighbors
          for (i = 4'd0; i < 4'd16; i = i + 4'd1) begin
            if (i < k) begin
              new_dev = cur_dev + base_diff[i];
              if (new_dev == 8'd0) begin
                // Reached 0 deviation: solution found
                steps_cur = steps_cur + 7'd1;
                state_next = S_DONE;
                done = 1'b1;
                min_liters = steps_cur;
                // Break out of loop; no need to enqueue further
              end else begin
                // Bounds check in [-127,127]
                if ((new_dev >= 8'sd-127) && (new_dev <= 8'sd127)) begin
                  new_dev_q = new_dev;
                  // Check visited for the new deviation (index = new_dev + 128)
                  if (!visited[new_dev_q + 8'sd128]) begin
                    // Mark visited now to avoid duplicates
                    visited[new_dev_q + 8'sd128] = 1'b1;
                    // Enqueue if space (guard against overflow)
                    if (next_tail_plus_one != head) begin
                      queue_val[tail] = new_dev_q;
                      queue_steps[tail] = steps_cur + 7'd1;
                      tail = next_tail_plus_one;
                    end
                  end
                end
              end
            end
          end

          if (state_next != S_DONE) begin
            // Continue BFS or exit if too many cycles (fail-safe)
            bfs_count = bfs_count + 6'd1;
            if (bfs_count >= 6'd63) begin
              // Hard upper bound safety
              state_next = S_DONE;
              done = 1'b1;
              min_liters = 7'd127; // -1 encoded
            end else begin
              state_next = S_BFS;
            end
          end
        end
      end

      S_DONE: begin
        // Hold done and result until next start
        done = 1'b1;
        min_liters = min_liters; // maintain last value
        if (start) begin
          state_next = S_INIT;
        end else begin
          state_next = S_DONE;
        end
      end

      default: begin
        state_next = S_IDLE;
      end
    endcase
  end
endmodule