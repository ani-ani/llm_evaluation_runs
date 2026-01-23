module badge_connectivity (
  input clk,
  input rst_n,
  input start,
  input [2:0] start_room,
  input [2:0] dest_room,
  input [5:0] num_locks,
  input [15:0] badge_min,
  input [15:0] badge_max,
  input [2:0] lock_from,
  input [2:0] lock_to,
  input [15:0] lock_range_min,
  input [15:0] lock_range_max,
  input lock_load,
  input lock_next,
  output reg [31:0] valid_badge_count,
  output reg done,
  output reg error
);

  // Parameters
  localparam IDLE = 3'b000;
  localparam LOAD_CONFIG = 3'b001;
  localparam PREPARE_SEARCH = 3'b010;
  localparam EXPLORE = 3'b011;
  localparam CALCULATE = 3'b100;
  localparam DONE = 3'b101;

  // Lock memory (16 locks max)
  reg [2:0] lock_mem_from [0:15];
  reg [2:0] lock_mem_to [0:15];
  reg [15:0] lock_mem_min [0:15];
  reg [15:0] lock_mem_max [0:15];
  reg [3:0] lock_count = 0;

  // BFS state
  reg [2:0] current_room;
  reg [7:0] visited_rooms = 0;
  reg [7:0] reachable_rooms = 0;
  reg [7:0] queue [0:7];
  reg [2:0] queue_head = 0;
  reg [2:0] queue_tail = 0;

  // Range tracking
  reg [15:0] current_min = 16'hFFFF;
  reg [15:0] current_max = 16'h0000;
  reg [15:0] global_min = 16'hFFFF;
  reg [15:0] global_max = 16'h0000;

  // State machine
  reg [2:0] state = IDLE;
  reg [31:0] cycle_count = 0;

  // Initialize outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_badge_count <= 32'h0;
      done <= 1'b0;
      error <= 1'b0;
      state <= IDLE;
      lock_count <= 0;
      visited_rooms <= 0;
      reachable_rooms <= 0;
      queue_head <= 0;
      queue_tail <= 0;
      current_min <= 16'hFFFF;
      current_max <= 16'h0000;
      global_min <= 16'hFFFF;
      global_max <= 16'h0000;
      cycle_count <= 0;
    end
  end

  // State machine logic
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled above
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PREPARE_SEARCH;
            cycle_count <= 0;
          end
        end

        LOAD_CONFIG: begin
          if (lock_load) begin
            if (lock_count < 16) begin
              lock_mem_from[lock_count] <= lock_from;
              lock_mem_to[lock_count] <= lock_to;
              lock_mem_min[lock_count] <= lock_range_min;
              lock_mem_max[lock_count] <= lock_range_max;
              lock_count <= lock_count + 1;
            end
          end else if (lock_next) begin
            // Ready for next lock
          end else if (start) begin
            state <= PREPARE_SEARCH;
          end
        end

        PREPARE_SEARCH: begin
          // Initialize BFS
          visited_rooms <= 0;
          reachable_rooms <= 0;
          queue_head <= 0;
          queue_tail <= 0;
          current_min <= 16'hFFFF;
          current_max <= 16'h0000;
          global_min <= 16'hFFFF;
          global_max <= 16'h0000;

          // Start from start_room
          queue[queue_tail] <= start_room;
          queue_tail <= queue_tail + 1;
          visited_rooms[start_room] <= 1'b1;

          state <= EXPLORE;
          cycle_count <= 0;
        end

        EXPLORE: begin
          if (queue_head < queue_tail) begin
            current_room <= queue[queue_head];
            queue_head <= queue_head + 1;

            // Check if we reached destination
            if (current_room == dest_room) begin
              reachable_rooms[dest_room] <= 1'b1;
            end

            // Explore all locks from current room
            for (int i = 0; i < lock_count; i = i + 1) begin
              if (lock_mem_from[i] == current_room && !visited_rooms[lock_mem_to[i]]) begin
                visited_rooms[lock_mem_to[i]] <= 1'b1;
                queue[queue_tail] <= lock_mem_to[i];
                queue_tail <= queue_tail + 1;

                // Update range for this path
                current_min <= (current_min < lock_mem_min[i]) ? current_min : lock_mem_min[i];
                current_max <= (current_max > lock_mem_max[i]) ? current_max : lock_mem_max[i];
              end
            end

            cycle_count <= cycle_count + 1;
            if (cycle_count > 200) begin
              state <= CALCULATE;
            end
          end else begin
            state <= CALCULATE;
          end
        end

        CALCULATE: begin
          // Compute intersection of all reachable paths
          if (reachable_rooms[dest_room]) begin
            // Find common range
            global_min <= (badge_min > current_min) ? badge_min : current_min;
            global_max <= (badge_max < current_max) ? badge_max : current_max;

            // Count valid badges
            if (global_max >= global_min) begin
              valid_badge_count <= global_max - global_min + 1;
              error <= 1'b0;
            end else begin
              valid_badge_count <= 32'h0;
              error <= 1'b1;
            end
          end else begin
            valid_badge_count <= 32'h0;
            error <= 1'b1;
          end

          state <= DONE;
        end

        DONE: begin
          done <= 1'b1;
          if (!start) begin
            done <= 1'b0;
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule