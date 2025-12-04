module badge_path_counter (
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

  // Local parameters
  localparam IDLE        = 3'b000;
  localparam INIT        = 3'b001;
  localparam CHECK_BADGE = 3'b010;
  localparam BFS         = 3'b011;
  localparam COUNT       = 3'b100;
  localparam FINISH      = 3'b101;

  // BFS FIFO configuration (max 4 rooms, width=2)
  localparam FIFO_W = 2;
  localparam FIFO_DEPTH = 4;
  localparam FIFO_PTR_W = 2;

  // Registers
  reg [2:0] state, next_state;
  reg [3:0] badge_id;                 // 1..10
  reg [3:0] valid_count;
  reg [2:0] steps_taken;              // 0..4, BFS up to 4 steps
  reg [1:0] current_edge;             // Edge index for lock lookup
  reg found_path;                     // Set when D is discovered

  // BFS Control flags
  reg bfs_ce;                         // BFS step enable (advance edge index and steps_taken)
  reg step_last;                      // High when we are at the last step of the BFS (steps_taken == 3)
  reg bfs_running;                    // High during BFS phase
  reg bfs_done;                       // High when BFS phase finished

  // FIFO queue storage and control
  reg [FIFO_W-1:0] queue [$];         // Unlimited unpacked array for behavioral sim
  reg [FIFO_PTR_W-1:0] q_wr_ptr;
  reg [FIFO_PTR_W-1:0] q_rd_ptr;
  reg q_empty;
  reg [FIFO_W-1:0] q_data_out;
  reg [1:0] pop_room;                 // Room popped from FIFO (combinatorial or registered)

  // Helpers for BFS
  reg [3:0] visited;                  // 4-bit visited mask
  wire [1:0] room_from;
  wire [1:0] room_to;
  wire [3:0] edge_min;
  wire [3:0] edge_max;
  wire edge_valid_by_badge;

  // State machine sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      badge_id <= 4'd0;
      valid_count <= 4'd0;
      result <= 4'd0;
      done <= 1'b0;
      found_path <= 1'b0;
      bfs_running <= 1'b0;
      bfs_done <= 1'b0;
      steps_taken <= 3'd0;
      current_edge <= 2'd0;
      visited <= 4'd0;
      q_wr_ptr <= 2'd0;
      q_rd_ptr <= 2'd0;
      q_empty <= 1'b1;
    end else begin
      // Default: maintain variables; assignments from control block below will update.
      state <= next_state;

      // BFS/phase control signals derived each cycle
      // BFS done is high when BFS is running and steps taken reached 4, and queue becomes empty
      if (bfs_running && (steps_taken == 3'd4)) begin
        // As soon as we finish 4 steps, the queue should be empty (we never push more than 4 rooms).
        bfs_done <= 1'b1;
      end else begin
        bfs_done <= 1'b0;
      end

      // Main control updates
      case (next_state)
        IDLE: begin
          badge_id <= 4'd0;
          valid_count <= 4'd0;
          result <= result;  // hold
          done <= 1'b0;
          found_path <= 1'b0;
          bfs_running <= 1'b0;
          steps_taken <= 3'd0;
          current_edge <= 2'd0;
          visited <= 4'd0;
          q_wr_ptr <= 2'd0;
          q_rd_ptr <= 2'd0;
          q_empty <= 1'b1;
        end

        INIT: begin
          // Reset BFS control for new badge
          found_path <= 1'b0;
          bfs_running <= 1'b0;
          bfs_done <= 1'b0;
          steps_taken <= 3'd0;
          current_edge <= 2'd0;
          visited <= 4'd0;
          q_wr_ptr <= 2'd0;
          q_rd_ptr <= 2'd0;
          q_empty <= 1'b1;
        end

        CHECK_BADGE: begin
          ///badge_id already set; we just go to BFS
          bfs_running <= 1'b1;
        end

        BFS: begin
          // BFS control progression
          if (bfs_ce) begin
            // Advance the BFS step
            steps_taken <= steps_taken + 1;
            if (current_edge == 2'd4)
              current_edge <= 2'd0;
            else
              current_edge <= current_edge + 1;
          end

          // Found path flag is sticky for this BFS run
          if (found_path) begin
            found_path <= 1'b1;
          end
        end

        COUNT: begin
          // Increment count if a path was found for this badge_id
          if (found_path) begin
            valid_count <= valid_count + 1;
          end
          // Prepare for next badge; clear found_path for next iteration
          found_path <= 1'b0;
        end

        FINISH: begin
          // Output final result and assert done
          result <= valid_count;
          done <= 1'b1;
        end

        default: begin
          // No change for unspecified states
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT;
      end
      INIT: begin
        next_state = CHECK_BADGE;
      end
      CHECK_BADGE: begin
        // Proceed to BFS for this badge_id
        next_state = BFS;
      end
      BFS: begin
        // BFS runs for fixed 4 steps; we do not break early to keep 3-cycle steps.
        if (bfs_done) next_state = COUNT;
        else next_state = BFS;
      end
      COUNT: begin
        if (badge_id < 4'd10)
          next_state = INIT;
        else
          next_state = FINISH;
      end
      FINISH: begin
        if (start) next_state = FINISH; // stay here until reset
        else next_state = FINISH;
      end
      default: next_state = IDLE;
    endcase
  end

  // BFS control signals combinational
  // step_last: when steps_taken == 3 (last step will be taken, after which steps_taken becomes 4)
  assign step_last = (steps_taken == 3'd3);
  // Enable BFS step when in BFS state and not at last step boundary
  assign bfs_ce = bfs_running && (steps_taken < 3'd4);

  // BFS edge selection and validation
  // Access current edge of lock database
  assign room_from = lock_src[current_edge];
  assign room_to   = lock_dst[current_edge];
  assign edge_min  = lock_min[current_edge];
  assign edge_max  = lock_max[current_edge];
  assign edge_valid_by_badge = (badge_id >= edge_min) && (badge_id <= edge_max);

  // BFS data path: FIFO + visited + found detection
  always @(*) begin
    // Default: no pop in this cycle unless we are advancing steps
    pop_room = 2'b0;
    q_data_out = 2'b0;
  end

  // Edge processing sequential logic within BFS state
  // This implements 3-cycle BFS step behavior implicitly via bfs_ce timing.
  always @(posedge clk) begin
    if (!rst_n) begin
      // Already reset in main block
    end else begin
      case (state)
        BFS: begin
          if (bfs_ce) begin
            // In this cycle, we pop the current_room from FIFO
            if (!q_empty) begin
              pop_room <= q_data_out;
            end else begin
              pop_room <= 2'b0; // don't care if empty
            end
          end else begin
            // Between BFS steps, pop_room is not used; maintain value
            pop_room <= pop_room;
          end
        end
        default: begin
          // pop_room not used outside BFS
        end
      endcase
    end
  end

  // FIFO control (push/pop, pointers, empty flag)
  // Queue push/pop decisions made combinatorially with registers updated on clock.
  wire [1:0] next_room;
  wire push_decision;   // 1 to push discovered neighbor this BFS step
  wire should_visit;    // 1 if edge is valid, direction matches, and room not visited

  // Discover next room via current edge (combinatorial)
  // Direction: edge from current frontier (pop_room) to room_to
  assign should_visit = (badge_id >= edge_min) &&
                        (badge_id <= edge_max) &&
                        (pop_room == room_from) &&
                        (|visited[room_to] === 1'b0); // not visited

  // Push neighbor if not visited yet and we are at a BFS step edge processing
  assign push_decision = (bfs_running && bfs_ce && should_visit);

  // Found path detection: if neighbor is D and we are pushing it
  always @(*) begin
    // Declarative approach: found_path is set in this block via blocking assignment; it will be latched later in BFS block
  end

  // Update found_path within BFS cycles
  always @(posedge clk) begin
    if (!rst_n) begin
      // Set in reset path
    end else begin
      case (state)
        BFS: begin
          if (bfs_ce && should_visit && (room_to == D)) begin
            found_path <= 1'b1;
          end
        end
        INIT, CHECK_BADGE, COUNT, FINISH, IDLE: begin
          // found_path controlled by next state logic and reset path
        end
        default: begin
        end
      endcase
    end
  end

  // FIFO logic (write pointer, read pointer, empty flag, data out)
  always @(posedge clk) begin
    if (!rst_n) begin
      q_wr_ptr <= 2'd0;
      q_rd_ptr <= 2'd0;
      q_empty <= 1'b1;
    end else begin
      case (state)
        INIT: begin
          // Reset queue pointers and empty; contents don't matter after INIT
          q_wr_ptr <= 2'd0;
          q_rd_ptr <= 2'd0;
          q_empty <= 1'b1;
        end
        CHECK_BADGE: begin
          // Push S into queue before BFS begins
          if (q_empty) begin
            // Initialize queue with start room
            q_wr_ptr <= 2'd1;  // written 1 item
            q_rd_ptr <= 2'd0;  // can read 1 item
            q_empty <= 1'b0;
          end else begin
            // If not empty (unexpected), maintain but still add S
            if ((q_wr_ptr + 1) != q_rd_ptr) begin
              q_wr_ptr <= q_wr_ptr + 1;
            end
            q_empty <= 1'b0;
          end
        end
        BFS: begin
          // Handle pushes and pops for this BFS step
          if (bfs_ce) begin
            // Pop happens this cycle (q_data_out read happens combinatorially)
            // The FIFO has 4 entries; we only pop if queue is not empty
            if (!q_empty) begin
              // Compute new read pointer
              if (q_rd_ptr == (FIFO_DEPTH - 1))
                q_rd_ptr <= 2'd0;
              else
                q_rd_ptr <= q_rd_ptr + 1;
              // Update empty flag after read attempt
              if ((q_wr_ptr == (q_rd_ptr + 1)) ||
                  ((q_wr_ptr == 0) && (q_rd_ptr == (FIFO_DEPTH - 1)))) begin
                // Was the only element
                q_empty <= 1'b1;
              end else begin
                q_empty <= 1'b0;
              end
            end else begin
              // Already empty: maintain
              q_empty <= 1'b1;
            end

            // Push neighbor if decision is 1 and not already full
            if (push_decision) begin
              // Enqueue room_to if not already full (no overflow for valid BFS)
              if (q_wr_ptr != (q_rd_ptr - 1)) begin
                // Safe to push
                q_wr_ptr <= (q_wr_ptr + 1);
                // Set empty flag false
                q_empty <= 1'b0;
              end else begin
                // Queue full; do not push (should not happen for 4 rooms max)
                q_empty <= q_empty; // no change
              end
            end else begin
              // No push this cycle
            end
          end else begin
            // Between BFS steps: do nothing
          end
        end
        default: begin
          // No change
        end
      endcase
    end
  end

  // Read data from FIFO; if empty, data_out is don't-care
  // This read is purely combinational (behavioral). Real hardware would use registered read.
  // Here we simulate a read by indexing the queue.
  // Note: In real synthesis, you would register read data or use a shift register.
  // For simulation correctness in this context, this read works with the queue as an associative array.
  // To keep semantics simple, we assume a single-entry front-of-queue accessible at q_rd_ptr.
  // This is acceptable for behavioral simulation with the given constraints.
  integer q_index;
  always @(*) begin
    q_data_out = 2'b0;
    // In a real behavioral queue, queue[q_rd_ptr] would be read, but SystemVerilog queue uses dynamic methods.
    // As a simplification, we compute q_data_out as the oldest element by iterating one step from rd_ptr.
    // Since the queue maximum is 4 and we use a ring pointer model, the data out is modeled combinatorially below.
  end

  // Combinatorial: front-of-queue data
  // For behavioral simulation we emulate FIFO read by picking the element at q_rd_ptr (if not empty).
  // We'll assign this using a behavioral queue model that allows front() and pop_front().
  // Instead of trying to index by pointer, we use SystemVerilog queue methods for simulation correctness.

  // To keep the implementation straightforward and correct for simulation, we manage the queue using SystemVerilog queue methods.
  // The pointer-based control above is used for fullness/emptiness checks; the actual data read uses the queue's front().

  // FIFO front/pop using SystemVerilog queue (simulation-friendly)
  // We manage the queue contents only via pushes and pops; emptiness and full checks are approximated.
  // For the purpose of the specified BFS (max 4 rooms), this approach is sufficient.

  // Behavioral FIFO management with methods
  reg queue_manage_en;
  always @(posedge clk) begin
    if (!rst_n) begin
      // Nothing queued
    end else begin
      case (state)
        CHECK_BADGE: begin
          // Enqueue start room S using queue push method
          // Guarantee room fits; queue capacity more than enough for 4 rooms.
          queue.push_back(S);
        end
        BFS: begin
          if (bfs_ce) begin
            // Pop front (if not empty)
            if (queue.size() > 0) begin
              pop_room = queue.pop_front();
            end
            // Check edge and possibly push neighbor
            if (should_visit) begin
              queue.push_back(room_to);
            end
          end
        end
        default: begin
          // No queue management here
        end
      endcase
    end
  end

  // For completeness, ensure a simple model for q_data_out is not used; we rely on the queue methods.
  // Populated room via queue.pop_front() above.

  // BFS run: increment badge_id after COUNT
  always @(posedge clk) begin
    if (!rst_n) begin
      // Values reset elsewhere
    end else begin
      case (state)
        COUNT: begin
          // Prepare for next badge (if any)
          if (badge_id < 4'd10) begin
            badge_id <= badge_id + 1;
          end
        end
        IDLE: begin
          badge_id <= 4'd0;
        end
        default: begin
          // badge_id handled in IDLE/INIT/COUNT
        end
      endcase
    end
  end

  // Idle when start is low in FINISH
  // The done signal is already registered in FINISH.

endmodule
