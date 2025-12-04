module badge_path_counter(
  input clk,
  input rst_n,
  input start,
  // Room configuration (max 4 rooms, 3 locks)
  input [1:0] S,
  input [1:0] D,
  // Lock database (5 locks max): each lock = [src, dst, min, max]
  input [1:0] lock_src[0:4],
  input [1:0] lock_dst[0:4],
  input [3:0] lock_min[0:4],
  input [3:0] lock_max[0:4],
  output reg [3:0] result,
  output reg done
);

  // FSM states
  typedef enum logic [2:0] {
    ST_IDLE   = 3'd0,
    ST_INIT   = 3'd1,
    ST_CHECK  = 3'd2,
    ST_BFS    = 3'd3,
    ST_COUNT  = 3'd4,
    ST_FINISH = 3'd5
  } state_t;

  state_t state, next_state;

  // Badge and result counters
  reg [3:0] badge_id;       // 1..10
  reg [3:0] valid_count;    // up to 10

  // BFS structures
  reg [3:0] visited;        // 1 bit/room

  // Queue: depth 4, stores room indices [1:0]
  reg [1:0] queue[0:3];
  reg [1:0] q_head;         // index to pop
  reg [1:0] q_tail;         // index to push
  reg [2:0] q_count;        // 0..4

  // Lock scan index for BFS
  reg [2:0] lock_idx;       // 0..4

  // BFS control flags
  reg       path_found;     // for current badge

  // Combinational helpers
  wire queue_empty = (q_count == 0);

  // Sequential FSM and datapath
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= ST_IDLE;
      badge_id    <= 4'd0;
      valid_count <= 4'd0;
      result      <= 4'd0;
      done        <= 1'b0;
      visited     <= 4'b0;
      q_head      <= 2'd0;
      q_tail      <= 2'd0;
      q_count     <= 3'd0;
      lock_idx    <= 3'd0;
      path_found  <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        ST_IDLE: begin
          done        <= 1'b0;
          result      <= 4'd0;
          if (start) begin
            // Prepare for new run
            badge_id    <= 4'd1;
            valid_count <= 4'd0;
            visited     <= 4'b0;
            q_head      <= 2'd0;
            q_tail      <= 2'd0;
            q_count     <= 3'd0;
            lock_idx    <= 3'd0;
            path_found  <= 1'b0;
          end
        end

        ST_INIT: begin
          // Initialize BFS for current badge_id
          visited              <= 4'b0;
          visited[S]           <= 1'b1;
          queue[0]             <= S;
          q_head               <= 2'd0;
          q_tail               <= 2'd1;  // one element enqueued
          q_count              <= 3'd1;
          lock_idx             <= 3'd0;
          path_found           <= (S == D); // if S==D, path exists trivially
        end

        ST_CHECK: begin
          // Entry to BFS processing: nothing extra; handled in ST_BFS
        end

        ST_BFS: begin
          if (!path_found && !queue_empty) begin
            // We perform a lock-by-lock scan for the current front node.
            // Current room at queue[q_head]
            reg [1:0] cur_room;
            cur_room = queue[q_head];

            // Examine current lock
            reg [1:0] lsrc, ldst;
            reg [3:0] lmin, lmax;
            lsrc = lock_src[lock_idx];
            ldst = lock_dst[lock_idx];
            lmin = lock_min[lock_idx];
            lmax = lock_max[lock_idx];

            // Check if this lock can be used with current badge_id
            if ((badge_id >= lmin) && (badge_id <= lmax) && (lsrc == cur_room)) begin
              // If destination not yet visited, mark and enqueue
              if (!visited[ldst]) begin
                visited[ldst] <= 1'b1;
                // Check if we reached destination
                if (ldst == D) begin
                  path_found <= 1'b1;
                end
                // Enqueue ldst if queue not full
                if (q_count < 4) begin
                  queue[q_tail] <= ldst;
                  q_tail        <= q_tail + 2'd1;
                  q_count       <= q_count + 3'd1;
                end
              end
            end

            // Advance lock index or pop current room
            if (lock_idx == 3'd4) begin
              // Finished scanning all locks for cur_room
              lock_idx <= 3'd0;
              // Pop from queue
              q_head   <= q_head + 2'd1;
              if (q_count != 0)
                q_count <= q_count - 3'd1;
            end else begin
              // Move to next lock for same room
              lock_idx <= lock_idx + 3'd1;
            end
          end
        end

        ST_COUNT: begin
          // Update valid_count for current badge
          if (path_found)
            valid_count <= valid_count + 4'd1;

          // Prepare next badge or finish
          if (badge_id == 4'd10) begin
            result <= valid_count + (path_found ? 4'd1 : 4'd0);
          end else begin
            // Advance to next badge: clear BFS state
            badge_id    <= badge_id + 4'd1;
            visited     <= 4'b0;
            q_head      <= 2'd0;
            q_tail      <= 2'd0;
            q_count     <= 3'd0;
            lock_idx    <= 3'd0;
            path_found  <= 1'b0;
          end
        end

        ST_FINISH: begin
          done <= 1'b1;
          // Hold result until next start
          if (start) begin
            // Start a new run immediately if requested
            done        <= 1'b0;
            badge_id    <= 4'd1;
            valid_count <= 4'd0;
            visited     <= 4'b0;
            q_head      <= 2'd0;
            q_tail      <= 2'd0;
            q_count     <= 3'd0;
            lock_idx    <= 3'd0;
            path_found  <= 1'b0;
          end
        end

        default: begin
          // Safety defaults
          state <= ST_IDLE;
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;

    case (state)
      ST_IDLE: begin
        if (start)
          next_state = ST_INIT;
      end

      ST_INIT: begin
        next_state = ST_CHECK;
      end

      ST_CHECK: begin
        // If S == D, path_found already set; still go through COUNT
        next_state = ST_BFS;
      end

      ST_BFS: begin
        if (path_found) begin
          // Found path for this badge
          next_state = ST_COUNT;
        end else if (queue_empty) begin
          // No more nodes to explore, no path
          next_state = ST_COUNT;
        end else begin
          // Continue BFS for this badge
          next_state = ST_BFS;
        end
      end

      ST_COUNT: begin
        if (badge_id == 4'd10) begin
          next_state = ST_FINISH;
        end else begin
          next_state = ST_INIT;
        end
      end

      ST_FINISH: begin
        if (start)
          next_state = ST_INIT;
        else
          next_state = ST_FINISH;
      end

      default: begin
        next_state = ST_IDLE;
      end
    endcase
  end

endmodule