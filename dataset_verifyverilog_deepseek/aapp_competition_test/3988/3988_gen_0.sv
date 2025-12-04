module graph_reachability_optimizer(
  input clk,
  input rst_n,
  input start,
  input [2:0] start_node,
  input [2:0] graph_nodes [0:15][0:2],
  input [3:0] edge_count,
  output reg [3:0] max_reachable, min_reachable,
  output reg [15:0] max_orient, min_orient,
  output reg done
);

  enum {RESET, PROCESS_MAX, PROCESS_MIN, DONE} state;
  reg [2:0] queue [0:7];
  reg [2:0] queue_head, queue_tail;
  reg [7:0] visited;
  reg [3:0] count;
  reg [2:0] current_node;
  reg processing;
  reg mode_max;
  reg [15:0] orient;

  wire [7:0] new_nodes;
  assign new_nodes[0] = !visited[0] && (
    |(graph_nodes[0][0] == 3'd1 && graph_nodes[0][1] == current_node && graph_nodes[0][2] == 3'd0) ||
    |(orient[0] && graph_nodes[0][0] == 3'd2 && (graph_nodes[0][1] == current_node && graph_nodes[0][2] == 3'd0 || graph_nodes[0][2] == current_node && graph_nodes[0][1] == 3'd0)));
  assign new_nodes[1] = !visited[1] && (
    |(graph_nodes[0][0] == 3'd1 && graph_nodes[0][1] == current_node && graph_nodes[0][2] == 3'd1) ||
    |(orient[0] && graph_nodes[0][0] == 3'd2 && (graph_nodes[0][1] == current_node && graph_nodes[0][2] == 3'd1 || graph_nodes[0][2] == current_node && graph_nodes[0][1] == 3'd1)));
  // Repeat similar assignments for new_nodes[2] to new_nodes[7] to save space
  assign new_nodes[2] = !visited[2] && (
    |(graph_nodes[0][0] == 3'd1 && graph_nodes[0][1] == current_node && graph_nodes[0][2] == 3'd2) ||
    |(orient[0] && graph_nodes[0][0] == 3'd2 && (graph_nodes[0][1] == current_node && graph_nodes[0][2] == 3'd2 || graph_nodes[0][2] == current_node && graph_nodes[0][1] == 3'd2)));
  assign new_nodes[3] = !visited[3] && (
    |(graph_nodes[0][0] == 3'd1 && graph_nodes[0][1] == current_node && graph_nodes[0][2] == 3'd3) ||
    |(orient[0] && graph_nodes[0][0] == 3'd2 && (graph_nodes[0][1] == current_node && graph_nodes[0][2] == 3'd3 || graph_nodes[0][2] == current_node && graph_nodes[0][1] == 3'd3)));
  assign new_nodes[4] = !visited[4] && (
    |(graph_nodes[0][0] == 3'd1 && graph_nodes[0][1] == current_node && graph_nodes[0][2] == 3'd4) ||
    |(orient[0] && graph_nodes[0][0] == 3'd2 && (graph_nodes[0][1] == current_node && graph_nodes[0][2] == 3'd4 || graph_nodes[0][2] == current_node && graph_nodes[0][1] == 3'd4)));
  assign new_nodes[5] = !visited[5] && (
    |(graph_nodes[0][0] == 3'd1 && graph_nodes[0][1] == current_node && graph_nodes[0][2] == 3'd5) ||
    |(orient[0] && graph_nodes[0][0] == 3'd2 && (graph_nodes[0][1] == current_node && graph_nodes[0][2] == 3'd5 || graph_nodes[0][2] == current_node && graph_nodes[0][1] == 3'd5)));
  assign new_nodes[6] = !visited[6] && (
    |(graph_nodes[0][0] == 3'd1 && graph_nodes[0][1] == current_node && graph_nodes[0][2] == 3'd6) ||
    |(orient[0] && graph_nodes[0][0] == 3'd2 && (graph_nodes[0][1] == current_node && graph_nodes[0][2] == 3'd6 || graph_nodes[0][2] == current_node && graph_nodes[0][1] == 3'd6)));
  assign new_nodes[7] = !visited[7] && (
    |(graph_nodes[0][0] == 3'd1 && graph_nodes[0][1] == current_node && graph_nodes[0][2] == 3'd7) ||
    |(orient[0] && graph_nodes[0][0] == 3'd2 && (graph_nodes[0][1] == current_node && graph_nodes[0][2] == 3'd7 || graph_nodes[0][2] == current_node && graph_nodes[0][1] == 3'd7)));

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= RESET;
      done <= 0;
      max_reachable <= 0;
      min_reachable <= 0;
      max_orient <= 0;
      min_orient <= 0;
      queue_head <= 0;
      queue_tail <= 0;
      visited <= 0;
      count <= 0;
    end else begin
      done <= 0;
      case (state)
        RESET: begin
          if (start) begin
            state <= PROCESS_MAX;
            max_orient <= 16'hFFFF;
            orient <= 16'hFFFF;
            mode_max <= 1;
            queue[0] <= start_node;
            queue_head <= 0;
            queue_tail <= 1;
            visited <= (1 << start_node);
            count <= 1;
          end
        end
        PROCESS_MAX: begin
          if (queue_head < queue_tail) begin
            current_node <= queue[queue_head];
            processing <= 1;
            queue_head <= queue_head + 1;
          end else if (processing) begin
            processing <= 0;
            visited <= visited | new_nodes;
            count <= count + new_nodes[0] + new_nodes[1] + new_nodes[2] + new_nodes[3] + new_nodes[4] + new_nodes[5] + new_nodes[6] + new_nodes[7];
            if (new_nodes[0]) begin queue[queue_tail] <= 3'd0; queue_tail <= queue_tail + 1; end
            if (new_nodes[1]) begin queue[queue_tail] <= 3'd1; queue_tail <= queue_tail + 1; end
            if (new_nodes[2]) begin queue[queue_tail] <= 3'd2; queue_tail <= queue_tail + 1; end
            if (new_nodes[3]) begin queue[queue_tail] <= 3'd3; queue_tail <= queue_tail + 1; end
            if (new_nodes[4]) begin queue[queue_tail] <= 3'd4; queue_tail <= queue_tail + 1; end
            if (new_nodes[5]) begin queue[queue_tail] <= 3'd5; queue_tail <= queue_tail + 1; end
            if (new_nodes[6]) begin queue[queue_tail] <= 3'd6; queue_tail <= queue_tail + 1; end
            if (new_nodes[7]) begin queue[queue_tail] <= 3'd7; queue_tail <= queue_tail + 1; end
          end else begin
            max_reachable <= count;
            min_orient <= 0;
            orient <= 0;
            mode_max <= 0;
            queue[0] <= start_node;
            queue_head <= 0;
            queue_tail <= 1;
            visited <= (1 << start_node);
            count <= 1;
            state <= PROCESS_MIN;
          end
        end
        PROCESS_MIN: begin
          if (queue_head < queue_tail) begin
            current_node <= queue[queue_head];
            processing <= 1;
            queue_head <= queue_head + 1;
          end else if (processing) begin
            processing <= 0;
            visited <= visited | new_nodes;
            count <= count + new_nodes[0] + new_nodes[1] + new_nodes[2] + new_nodes[3] + new_nodes[4] + new_nodes[5] + new_nodes[6] + new_nodes[7];
            if (new_nodes[0]) begin queue[queue_tail] <= 3'd0; queue_tail <= queue_tail + 1; end
            if (new_nodes[1]) begin queue[queue_tail] <= 3'd1; queue_tail <= queue_tail + 1; end
            if (new_nodes[2]) begin queue[queue_tail] <= 3'd2; queue_tail <= queue_tail + 1; end
            if (new_nodes[3]) begin queue[queue_tail] <= 3'd3; queue_tail <= queue_tail + 1; end
            if (new_nodes[4]) begin queue[queue_tail] <= 3'd4; queue_tail <= queue_tail + 1; end
            if (new_nodes[5]) begin queue[queue_tail] <= 3'd5; queue_tail <= queue_tail + 1; end
            if (new_nodes[6]) begin queue[queue_tail] <= 3'd6; queue_tail <= queue_tail + 1; end
            if (new_nodes[7]) begin queue[queue_tail] <= 3'd7; queue_tail <= queue_tail + 1; end
          end else begin
            min_reachable <= count;
            done <= 1;
            state <= DONE;
          end
        end
        DONE: begin
          state <= RESET;
        end
      endcase
    end
  end
endmodule