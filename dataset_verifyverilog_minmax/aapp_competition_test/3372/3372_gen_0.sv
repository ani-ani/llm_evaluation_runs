module flight_path_finder(
  input clk,
  input rst_n,
  input start,
  input [2:0] N,
  input [2:0] s,
  input [2:0] t,
  input [7:0] adj_types,
  input [7:0][7:0] adj_lists,
  output reg [3:0] hops,
  output reg done,
  output reg impossible
);

  // BFS state machine
  localparam IDLE = 2'b00;
  localparam BUILD_MATRIX = 2'b01;
  localparam BFS = 2'b10;
  localparam DONE = 2'b11;

  reg [1:0] state, next_state;
  reg [5:0] cycle_count;  // up to 63 for 32-cycle limit
  reg [2:0] i, j;         // loop indices
  reg [2:0] cur;          // current node (BFS front)
  reg [7:0] visited;      // visited airports
  reg [2:0] dist [0:7];   // hop distance to each airport (0-7)
  reg [2:0] head, tail;   // queue pointers (circular, 8-entry)
  reg [2:0] queue [0:7];  // BFS queue (3-bit node ids)
  reg [7:0][7:0] adj_matrix; // 8x8 adjacency matrix (1 bit per entry)
  reg found;              // target found flag
  reg bfs_active;         // BFS active flag
  reg [3:0] result_hops;  // result hops to report
  reg result_impossible;  // result impossible flag

  integer k;

  // Build adjacency matrix in 8 cycles (max N=8)
  always @(*) begin
    for (i = 0; i < 8; i = i + 1) begin
      for (j = 0; j < 8; j = j + 1) begin
        adj_matrix[i][j] = (adj_types[i] == 1'b0) ? adj_lists[i][j] : ~adj_lists[i][j];
      end
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = BUILD_MATRIX;
      end
      BUILD_MATRIX: begin
        next_state = BFS;
      end
      BFS: begin
        if (found) next_state = DONE;
        else if (cycle_count >= 31) next_state = DONE; // 32-cycle timeout
        else if (head == tail) next_state = DONE;     // queue empty -> no path
      end
      DONE: begin
        next_state = IDLE;
      end
    endcase
  end

  // State and BFS updates
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      impossible <= 1'b0;
      hops <= 4'b0;
      cycle_count <= 6'b0;
      found <= 1'b0;
      bfs_active <= 1'b0;
      result_hops <= 4'b0;
      result_impossible <= 1'b0;
      head <= 3'b0;
      tail <= 3'b0;
      cur <= 3'b0;
      visited <= 8'b0;
      for (k = 0; k < 8; k = k + 1) dist[k] <= 3'b0;
    end else begin
      // Update state machine
      state <= next_state;

      // Default outputs; they will be set appropriately in DONE
      done <= 1'b0;
      // impossible and hops hold previous values until DONE updates them

      case (next_state)
        IDLE: begin
          if (start) begin
            // Clear BFS state when a new computation starts
            cycle_count <= 6'b0;
            found <= 1'b0;
            bfs_active <= 1'b1;
            result_hops <= 4'b0;
            result_impossible <= 1'b0;
            head <= 3'b0;
            tail <= 3'b0;
            cur <= 3'b0;
            visited <= 8'b0;
            for (k = 0; k < 8; k = k + 1) dist[k] <= 3'b0;
          end else begin
            bfs_active <= 1'b0;
          end
        end

        BUILD_MATRIX: begin
          // Matrix is built combinatorially via continuous assign.
          // No sequential state here.
        end

        BFS: begin
          cycle_count <= cycle_count + 1;
          if (head != tail) begin
            // Pop front node
            cur <= queue[head];
            head <= head + 1;

            // Explore neighbors (0..N-1)
            for (j = 0; j < 8; j = j + 1) begin
              if (j < N && adj_matrix[cur][j] && !visited[j]) begin
                visited[j] <= 1'b1;
                dist[j] <= dist[cur] + 1;
                if (j == t) begin
                  found <= 1'b1;
                  result_hops <= {1'b0, dist[cur] + 1};
                  result_impossible <= 1'b0;
                end else begin
                  // Enqueue if not full
                  if (tail != (head - 1)) begin
                    queue[tail] <= j;
                    tail <= tail + 1;
                  end
                end
              end
            end
          end
        end

        DONE: begin
          done <= 1'b1;
          if (found) begin
            hops <= result_hops;
            impossible <= 1'b0;
          end else begin
            // No path found or timeout
            hops <= 4'b1111; // 0xF for impossible
            impossible <= 1'b1;
          end
          // Prepare for next operation
          found <= 1'b0;
          bfs_active <= 1'b0;
        end
      endcase
    end
  end

endmodule
