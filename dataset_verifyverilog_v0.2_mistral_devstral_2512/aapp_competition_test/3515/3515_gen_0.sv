module chile_shortest_path (
  input clk,
  input rst_n,
  input start,
  input [7:0] valid_nodes,
  input [15:0] y_coords [0:7],
  input [15:0] d_mins [0:7],
  input [15:0] r_times [0:7],
  output reg [15:0] dist [0:7],
  output reg done
);

  // Constants
  localparam IDLE = 3'b000;
  localparam SELECT_MIN = 3'b001;
  localparam UPDATE_NEIGHBORS = 3'b010;
  localparam CHECK_COMPLETION = 3'b011;
  localparam FINISHED = 3'b100;

  // State machine
  reg [2:0] state = IDLE;
  reg [2:0] next_state = IDLE;

  // Internal registers
  reg [2:0] iteration = 0;
  reg [2:0] current_node = 0;
  reg [2:0] neighbor_node = 0;
  reg [15:0] min_dist = 16'hFFFF;
  reg [7:0] visited = 0;
  reg [15:0] temp_dist [0:7];

  // Initialize distances
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      for (int i = 0; i < 8; i = i + 1) begin
        dist[i] <= 16'hFFFF;
      end
      dist[0] <= 0;
      visited <= 0;
      iteration <= 0;
    end else if (start && state == IDLE) begin
      state <= SELECT_MIN;
      done <= 0;
      for (int i = 0; i < 8; i = i + 1) begin
        dist[i] <= 16'hFFFF;
      end
      dist[0] <= 0;
      visited <= 0;
      iteration <= 0;
    end else begin
      state <= next_state;
    end
  end

  // State machine logic
  always @(*) begin
    case (state)
      IDLE: begin
        if (start) next_state = SELECT_MIN;
        else next_state = IDLE;
      end
      SELECT_MIN: begin
        min_dist = 16'hFFFF;
        current_node = 0;
        for (int i = 0; i < 8; i = i + 1) begin
          if (valid_nodes[i] && !visited[i] && dist[i] < min_dist) begin
            min_dist = dist[i];
            current_node = i;
          end
        end
        if (min_dist == 16'hFFFF) next_state = CHECK_COMPLETION;
        else next_state = UPDATE_NEIGHBORS;
      end
      UPDATE_NEIGHBORS: begin
        for (int i = 0; i < 8; i = i + 1) begin
          if (valid_nodes[i] && !visited[i]) begin
            if (y_coords[current_node] - y_coords[i] >= d_mins[current_node] ||
                y_coords[i] - y_coords[current_node] >= d_mins[current_node]) begin
              temp_dist[i] = dist[current_node] + r_times[current_node] + 
                            (y_coords[current_node] > y_coords[i] ? 
                             y_coords[current_node] - y_coords[i] : 
                             y_coords[i] - y_coords[current_node]);
              if (temp_dist[i] < dist[i]) begin
                dist[i] = temp_dist[i];
              end
            end
          end
        end
        visited[current_node] = 1;
        iteration = iteration + 1;
        next_state = CHECK_COMPLETION;
      end
      CHECK_COMPLETION: begin
        if (iteration == 8 || min_dist == 16'hFFFF) begin
          next_state = FINISHED;
        end else begin
          next_state = SELECT_MIN;
        end
      end
      FINISHED: begin
        done = 1;
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

endmodule