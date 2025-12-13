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

  // State encoding
  localparam IDLE   = 2'd0;
  localparam INIT   = 2'd1;
  localparam BFS    = 2'd2;
  localparam FINISH = 2'd3;

  reg [1:0] state, next_state;

  // base_diffs: signed deviations in range [-127,127]
  reg signed [7:0] base_diffs [0:15];

  // BFS queue: up to 128 entries, each {deviation, steps}
  reg signed [7:0] q_dev   [0:127];
  reg [6:0]        q_steps [0:127];

  reg [6:0] head;        // dequeue pointer (0-127)
  reg [6:0] tail;        // enqueue pointer (0-127)
  reg [7:0] q_count;     // number of elements in queue (0-128)

  // visited deviations: 256 bits, index = deviation + 128
  reg [255:0] visited;

  // iterator for initialization and BFS expansion
  reg [4:0] idx; // supports up to 16

  // current node
  reg  signed [7:0] cur_dev;
  reg  [6:0]        cur_steps;

  // control flags
  reg found_zero;
  reg [6:0] found_steps;

  // Combinational clamp for base_diffs computation (done sequentially in INIT)
  function automatic signed [7:0] clamp_diff;
    input signed [10:0] diff; // 10-bit minus 10-bit -> up to 11 bits signed
    begin
      if (diff > 11'sd127)
        clamp_diff = 8'sd127;
      else if (diff < -11'sd127)
        clamp_diff = -8'sd127;
      else
        clamp_diff = diff[7:0];
    end
  endfunction

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = INIT;
      end
      INIT: begin
        // After computing base_diffs and priming queue, move to BFS
        // Transition handled in sequential block once idx done
        // Keep default here; overridden by conditions there
      end
      BFS: begin
        // Move to FINISH when solution found or queue empty
        // Actual decision in sequential block; keep here
      end
      FINISH: begin
        // Wait until next start (handled sequentially)
        // Stay in FINISH until new start
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      min_liters  <= 7'b1111111;
      done        <= 1'b0;
      head        <= 7'd0;
      tail        <= 7'd0;
      q_count     <= 8'd0;
      visited     <= 256'd0;
      idx         <= 5'd0;
      found_zero  <= 1'b0;
      found_steps <= 7'd0;
      for (i = 0; i < 16; i = i + 1) begin
        base_diffs[i] <= 8'sd0;
      end
      for (i = 0; i < 128; i = i + 1) begin
        q_dev[i]   <= 8'sd0;
        q_steps[i] <= 7'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done        <= 1'b0;
          min_liters  <= 7'b1111111;
          found_zero  <= 1'b0;
          found_steps <= 7'd0;
          if (start) begin
            // Initialize for new run
            idx      <= 5'd0;
            visited  <= 256'd0;
            head     <= 7'd0;
            tail     <= 7'd0;
            q_count  <= 8'd0;
            // next_state to INIT via comb
          end
        end

        INIT: begin
          // Build base_diffs one per cycle until idx == k
          if (idx < k) begin
            // Compute diff = concentrations[idx] - target_n (signed)
            // 11 bits signed range: -1024..+1023
            // Cast to signed explicitly
            begin : gen_diff
              reg signed [10:0] diff_s;
              diff_s = $signed({1'b0, concentrations[idx]}) - $signed({1'b0, target_n});
              base_diffs[idx] <= clamp_diff(diff_s);
            end
            idx <= idx + 5'd1;
          end else begin
            // After all base_diffs[0..k-1] computed
            // Initialize BFS from deviation 0, steps 0
            visited <= 256'd0;
            visited[8'd128] <= 1'b1; // deviation 0 -> index 128

            q_dev[0]   <= 8'sd0;
            q_steps[0] <= 7'd0;
            head       <= 7'd0;
            tail       <= 7'd1;
            q_count    <= 8'd1;

            found_zero  <= 1'b0;
            found_steps <= 7'd0;
            idx         <= 5'd0;

            state <= BFS; // explicit override of next_state
          end
        end

        BFS: begin
          done <= 1'b0;

          if (!found_zero) begin
            if (q_count == 0) begin
              // No solution
              min_liters <= 7'b1111111; // 127 indicates -1
              done       <= 1'b1;
              state      <= FINISH;
            end else begin
              // Dequeue current node
              cur_dev   <= q_dev[head];
              cur_steps <= q_steps[head];

              // Prepare next head and decrement count
              head    <= head + 7'd1;
              q_count <= q_count - 8'd1;

              // Expand neighbors sequentially over k cycles using idx
              if (idx < k) begin
                // For the current idx, compute new deviation and possibly enqueue
                begin : expand
                  reg signed [7:0] nd;
                  reg [7:0]       nd_idx;
                  reg             was_visited;
                  nd = q_dev[head] + base_diffs[idx];

                  // Clamp nd into [-127,127]
                  if (nd > 8'sd127)
                    nd = 8'sd127;
                  else if (nd < -8'sd127)
                    nd = -8'sd127;

                  nd_idx = nd + 8'd128;
                  was_visited = visited[nd_idx];

                  if (!was_visited) begin
                    visited[nd_idx] <= 1'b1;

                    if (nd == 8'sd0 && q_steps[head] + 7'd1 <= 7'd127) begin
                      // Found minimal steps (BFS order guarantees minimality)
                      found_zero  <= 1'b1;
                      found_steps <= q_steps[head] + 7'd1;
                    end else if (q_count < 8'd128 && q_steps[head] + 7'd1 <= 7'd127) begin
                      // Enqueue new node if queue not full and steps in range
                      q_dev[tail]   <= nd;
                      q_steps[tail] <= q_steps[head] + 7'd1;
                      tail          <= tail + 7'd1;
                      q_count       <= q_count + 8'd1;
                    end
                  end
                end
                idx <= idx + 5'd1;
              end else begin
                // Finished expanding all k neighbors for this node
                idx <= 5'd0;

                if (found_zero) begin
                  min_liters <= found_steps;
                  done       <= 1'b1;
                  state      <= FINISH;
                end else if (q_count == 0) begin
                  // Queue empty after expansion, no solution
                  min_liters <= 7'b1111111;
                  done       <= 1'b1;
                  state      <= FINISH;
                end
              end
            end
          end else begin
            // Safety: if found_zero latched, finalize
            min_liters <= found_steps;
            done       <= 1'b1;
            state      <= FINISH;
          end
        end

        FINISH: begin
          // Hold result until a new start pulse
          if (start) begin
            // Re-initialize for next run
            done        <= 1'b0;
            min_liters  <= 7'b1111111;
            visited     <= 256'd0;
            head        <= 7'd0;
            tail        <= 7'd0;
            q_count     <= 8'd0;
            idx         <= 5'd0;
            found_zero  <= 1'b0;
            found_steps <= 7'd0;
            state       <= INIT;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule