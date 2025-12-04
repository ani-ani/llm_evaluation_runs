module max_flow(
  input clk,
  input rst_n,
  input start,
  input [2:0] node_count,
  input [3:0] edge_count,
  input [47:0] edges [0:15],
  output reg [15:0] flow,
  output reg done
);

typedef enum logic [2:0] {IDLE, INIT, BFS_INIT, BFS_STEP, BFS_CHECK, AUGMENT, UPDATE, DONE} state_t;

state_t state, next_state;
logic [2:0] sink;
logic [2:0] node_i, node_j;
logic [2:0] current_node;
logic [2:0] queue [0:7];
logic [2:0] front, rear;
logic [7:0] visited;
logic [2:0] parent [0:7];
logic [15:0] residual [0:7][0:7];
logic [3:0] edge_index;
logic [19:0] flow_reg;
logic [7:0] cycle_counter;
logic found_path;
logic [2:0] path_node;
logic [15:0] min_resid;
logic [2:0] u, v;
logic [2:0] temp_node;

assign sink = node_count - 1'd1;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 1'b0;
    flow <= 16'h0;
    flow_reg <= 20'h0;
    edge_index <= 4'h0;
    cycle_counter <= 8'h0;
    for (int i = 0; i < 8; i++) begin
      parent[i] <= 3'h0;
      for (int j = 0; j < 8; j++) begin
        residual[i][j] <= 16'h0;
      end
    end
  end else begin
    state <= next_state;
    case (state)
      IDLE: begin
        flow_reg <= 20'h0;
        done <= 1'b0;
        cycle_counter <= 8'h0;
        if (start) begin
          edge_index <= 4'h0;
          next_state <= INIT;
          for (int i = 0; i < 8; i++) begin
            for (int j = 0; j < 8; j++) begin
              residual[i][j] <= 16'h0;
            end
          end
        end
      end
      
      INIT: begin
        u <= edges[edge_index][47:45];
        v <= edges[edge_index][44:42];
        residual[u][v] <= edges[edge_index][15:0];
        if (edge_index == edge_count) next_state <= BFS_INIT;
        else edge_index <= edge_index + 1;
      end
      
      BFS_INIT: begin
        visited <= 8'h0;
        for (int i = 0; i < 8; i++) parent[i] <= 3'h7;
        front <= 3'h0;
        rear <= 3'h1;
        queue[0] <= 3'h0;
        visited[0] <= 1'b1;
        parent[0] <= 3'h0;
        current_node <= 3'h0;
        found_path <= 1'b0;
        next_state <= BFS_STEP;
      end
      
      BFS_STEP: begin
        if (front == rear) begin
          next_state <= DONE;
        end else begin
          current_node <= queue[front];
          front <= front + 1;
          next_state <= BFS_CHECK;
        end
      end
      
      BFS_CHECK: begin
        for (node_i = 0; node_i < 8; node_i++) begin
          if (residual[current_node][node_i] > 0 && !visited[node_i]) begin
            visited[node_i] <= 1'b1;
            parent[node_i] <= current_node;
            queue[rear] <= node_i;
            rear <= rear + 1;
            if (node_i == sink) found_path <= 1'b1;
          end
        end
        if (found_path) next_state <= AUGMENT;
        else next_state <= BFS_STEP;
      end
      
      AUGMENT: begin
        path_node <= sink;
        min_resid <= 16'hFFFF;
        next_state <= UPDATE;
        temp_node <= parent[sink];
      end
      
      UPDATE: begin
        while (path_node != 3'h0) begin
          if (residual[temp_node][path_node] < min_resid)
            min_resid <= residual[temp_node][path_node];
          path_node <= temp_node;
          temp_node <= parent[temp_node];
        end
        flow_reg <= flow_reg + min_resid;
        path_node <= sink;
        temp_node <= parent[sink];
        next_state <= UPDATE_RESIDUAL;
      end
      
      UPDATE_RESIDUAL: begin
        while (path_node != 3'h0) begin
          residual[temp_node][path_node] <= residual[temp_node][path_node] - min_resid;
          residual[path_node][temp_node] <= residual[path_node][temp_node] + min_resid;
          path_node <= temp_node;
          temp_node <= parent[temp_node];
        end
        next_state <= BFS_INIT;
      end
      
      DONE: begin
        done <= 1'b1;
        flow <= flow_reg[15:0];
        if (start) next_state <= IDLE;
      end
      
      default: next_state <= IDLE;
    endcase
    
    if (state != IDLE && state != DONE) cycle_counter <= cycle_counter + 1;
    if (cycle_counter == 8'hFF) begin
      done <= 1'b1;
      flow <= flow_reg[15:0];
      next_state <= DONE;
    end
  end
end

always_comb begin
  next_state = state;
  case (state)
    IDLE: if (start) next_state = INIT;
    INIT: if (edge_index == edge_count) next_state = BFS_INIT;
    BFS_STEP: if (front == rear) next_state = DONE;
  endcase
end

endmodule