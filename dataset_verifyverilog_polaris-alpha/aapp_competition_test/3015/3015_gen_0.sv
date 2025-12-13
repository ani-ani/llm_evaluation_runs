module hamster_navigator(
  input clk,
  input rst_n,
  input start,
  input [1:0] start_node,
  input [1:0] bed_node,
  input [255:0] graph_data,
  input [3:0] edge_count,
  output reg [15:0] min_time,
  output reg infinity,
  output reg done
);

  // State machine encoding
  localparam IDLE = 2'd0;
  localparam CALC = 2'd1;
  localparam DONE = 2'd2;

  reg [1:0] state, next_state;

  // Distances/time for 8 states: {node[1:0], turn}
  // index = {turn, node}
  reg [15:0] best_time [0:7];

  // Working registers
  reg [15:0] cur_time;
  reg [1:0] cur_node;
  reg cur_turn; // 0 = minimizing (left), 1 = maximizing (right)

  reg [3:0] step_cnt;   // up to 8 steps
  reg [4:0] cyc_cnt;    // for 16 cycle max

  // Edge iteration
  reg [3:0] edge_idx;
  reg [3:0] max_weight;
  reg [15:0] best_local_time;
  reg [15:0] new_time;

  reg evaluating_neighbors;

  // Wires for current edge fields
  wire [3:0] edge_word_idx;
  wire [15:0] edge_word;
  wire [1:0] edge_start_node;
  wire [1:0] edge_end_node;
  wire [3:0] edge_weight;

  assign edge_word_idx = edge_idx;
  assign edge_word = graph_data[edge_word_idx*16 +: 16];
  assign edge_start_node = edge_word[15:14];
  assign edge_end_node   = edge_word[13:12];
  assign edge_weight     = edge_word[11:8];

  integer i;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      infinity <= 1'b0;
      min_time <= 16'd0;
      cur_time <= 16'd0;
      cur_node <= 2'd0;
      cur_turn <= 1'b0;
      step_cnt <= 4'd0;
      cyc_cnt <= 5'd0;
      edge_idx <= 4'd0;
      max_weight <= 4'd0;
      best_local_time <= 16'hFFFF;
      evaluating_neighbors <= 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        best_time[i] <= 16'hFFFF;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          infinity <= 1'b0;
          cyc_cnt <= 5'd0;
          step_cnt <= 4'd0;
          edge_idx <= 4'd0;
          evaluating_neighbors <= 1'b0;
          if (start) begin
            // Initialize best times
            for (i = 0; i < 8; i = i + 1) begin
              best_time[i] <= 16'hFFFF;
            end
            // Start state: start_node, turn = 0 (left/minimizing)
            cur_node <= start_node;
            cur_turn <= 1'b0;
            cur_time <= 16'd0;
            best_time[{1'b0, start_node}] <= 16'd0;
            best_local_time <= 16'hFFFF;
            max_weight <= 4'd0;
            edge_idx <= 4'd0;
            evaluating_neighbors <= 1'b1;
          end
        end

        CALC: begin
          cyc_cnt <= cyc_cnt + 5'd1;

          if (evaluating_neighbors) begin
            if (edge_idx < edge_count) begin
              // Process one edge per cycle
              if (edge_start_node == cur_node && edge_weight != 4'd0) begin
                new_time = cur_time + edge_weight;
                if (cur_turn == 1'b0) begin
                  // Minimizing turn: track best (min) of outgoing edges
                  if (new_time < best_local_time)
                    best_local_time <= new_time;
                end else begin
                  // Maximizing turn: track max weight, choose largest new_time
                  if (edge_weight > max_weight) begin
                    max_weight <= edge_weight;
                    best_local_time <= new_time;
                  end
                end
              end
              edge_idx <= edge_idx + 4'd1;
            end else begin
              // Finished scanning all edges for this state
              evaluating_neighbors <= 1'b0;

              if (best_local_time == 16'hFFFF) begin
                // No outgoing edges
                infinity <= 1'b1;
                min_time <= 16'hFFFF;
              end else begin
                // Advance to next state (toggle turn, for simplicity keep node)
                cur_time <= best_local_time;
                cur_turn <= ~cur_turn;
                // Heuristic: keep same node (abstracted alternating control)
                cur_node <= cur_node;
                if (best_time[{cur_turn, cur_node}] > best_local_time)
                  best_time[{cur_turn, cur_node}] <= best_local_time;

                step_cnt <= step_cnt + 4'd1;

                // Check bed reached (whenever current node equals bed_node)
                if (cur_node == bed_node) begin
                  min_time <= best_local_time;
                  infinity <= 1'b0;
                end

                // Prepare for next iteration
                best_local_time <= 16'hFFFF;
                max_weight <= 4'd0;
                edge_idx <= 4'd0;
                evaluating_neighbors <= 1'b1;
              end
            end
          end
        end

        DONE: begin
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = CALC;
      end

      CALC: begin
        // Termination conditions
        if (cyc_cnt >= 5'd16 || step_cnt >= 4'd8) begin
          next_state = DONE;
        end else if (!evaluating_neighbors && infinity) begin
          next_state = DONE;
        end else if (!evaluating_neighbors && (cur_node == bed_node)) begin
          next_state = DONE;
        end else begin
          next_state = CALC;
        end
      end

      DONE: begin
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule