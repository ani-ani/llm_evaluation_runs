module frog_jump_max_distance(
  input clk, // system clock
  input rst_n, // active-low reset
  input start, // pulse high to start computation
  input [3:0] N, // number of pebbles (1-16)
  input [15:0] spots [0:15], // spot counts for up to 16 pebbles
  output reg [3:0] max_distance, // 0-based index of farthest reachable pebble
  output reg done // high when computation complete
);

  // Internal registers
  reg [15:0] visited;        // visited flags for up to 16 pebbles
  reg [3:0]  queue [0:15];   // BFS queue indices
  reg [3:0]  head;           // queue head pointer
  reg [3:0]  tail;           // queue tail pointer
  reg        running;        // indicates BFS in progress
  reg [3:0]  curr_idx;       // current node index being expanded

  integer j;

  // Sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous reset
      visited      <= 16'b0;
      head         <= 4'd0;
      tail         <= 4'd0;
      running      <= 1'b0;
      curr_idx     <= 4'd0;
      max_distance <= 4'd0;
      done         <= 1'b0;
      // Clear queue contents (optional for simulation cleanliness)
      for (j = 0; j < 16; j = j + 1) begin
        queue[j] <= 4'd0;
      end
    end else begin
      if (start && !running) begin
        // Start a new BFS when start is pulsed and not already running
        visited      <= 16'b0;
        head         <= 4'd0;
        tail         <= 4'd0;
        max_distance <= 4'd0;
        done         <= 1'b0;
        running      <= 1'b1;

        // Initialize with pebble 0 only if N > 0
        if (N != 4'd0) begin
          visited[0] <= 1'b1;
          queue[0]   <= 4'd0;
          tail       <= 4'd1; // one element in queue
        end else begin
          // No pebbles: immediately done
          running <= 1'b0;
          done    <= 1'b1;
        end
      end else if (running) begin
        // BFS processing: one node expansion per cycle
        if (head != tail) begin
          curr_idx <= queue[head];
          head     <= head + 4'd1;

          // Explore all possible next pebbles in parallel
          for (j = 0; j < 16; j = j + 1) begin
            if ((j < N) && (j != queue[head]) && !visited[j]) begin
              if (spots[queue[head]] + spots[j] == (j[3:0] - queue[head])) begin
                visited[j] <= 1'b1;
                queue[tail] <= j[3:0];
                tail <= tail + 4'd1;
                if (j[3:0] > max_distance)
                  max_distance <= j[3:0];
              end
            end
          end
        end else begin
          // Queue empty: BFS complete
          running <= 1'b0;
          done    <= 1'b1;
        end
      end else begin
        // Idle state: hold done until next start
        done <= done;
      end
    end
  end

endmodule