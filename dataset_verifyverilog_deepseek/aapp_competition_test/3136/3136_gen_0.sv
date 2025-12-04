module delivery_distance(
  input clk,
  input rst_n,
  input start,
  input [2:0] warehouse1,
  input [2:0] warehouse2,
  input [2:0] employees [0:7],
  input [2:0] clients [0:7],
  input [7:0] num_deliveries,
  input [7:0] adj_matrix [0:7][0:7],
  output reg [15:0] total_distance,
  output reg done
);

typedef enum logic [2:0] {IDLE, COMPUTE_W1, COMPUTE_W2, MATCH_DELIVERIES, DONE} state_t;
state_t current_state, next_state;

reg [7:0] dist_w1 [0:7];
reg [7:0] dist_w2 [0:7];
reg [7:0] visited_w1, visited_w2;
reg [2:0] current_node;
reg [3:0] cycle_count;
reg [7:0] used_employees;
reg [15:0] acc_distance;
reg [2:0] delivery_count;
reg [2:0] min_node;
reg [7:0] min_dist;
reg [2:0] target;
reg [2:0] employee_idx;

function [7:0] min(input [7:0] a, input [7:0] b);
  min = (a < b) ? a : b;
endfunction

function [7:0] get_min_node(input [7:0] dist[0:7], input [7:0] visited);
  reg [7:0] min_val = 8'hFF;
  reg [2:0] min_node = 3'h0;
  for (int i=0; i<8; i=i+1) begin
    if (!visited[i] && dist[i] < min_val) begin
      min_val = dist[i];
      min_node = i;
    end
  end
  return min_node;
endfunction

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    current_state <= IDLE;
    done <= 1'b0;
    total_distance <= 16'h0;
    cycle_count <= 4'h0;
    delivery_count <= 3'h0;
    used_employees <= 8'h00;
    acc_distance <= 16'h0;
  end else begin
    current_state <= next_state;
    case (current_state)
      IDLE: begin
        done <= 1'b0;
        acc_distance <= 16'h0;
        used_employees <= 8'h00;
        delivery_count <= 3'h0;
        if (start) begin
          for (int i=0; i<8; i=i+1) begin
            dist_w1[i] <= (i == warehouse1) ? 8'h00 : 8'hFF;
            dist_w2[i] <= (i == warehouse2) ? 8'h00 : 8'hFF;
          end
          visited_w1 <= 8'h01 << warehouse1;
          visited_w2 <= 8'h01 << warehouse2;
          cycle_count <= 4'h1;
        end
      end

      COMPUTE_W1: begin
        min_node <= get_min_node(dist_w1, visited_w1);
        visited_w1 <= visited_w1 | (8'h01 << min_node);
        for (int i=0; i<8; i=i+1) begin
          if (!visited_w1[i] && adj_matrix[min_node][i] != 0) begin
            dist_w1[i] <= min(dist_w1[i], dist_w1[min_node] + adj_matrix[min_node][i]);
          end
        end
        cycle_count <= cycle_count + 1;
      end

      COMPUTE_W2: begin
        min_node <= get_min_node(dist_w2, visited_w2);
        visited_w2 <= visited_w2 | (8'h01 << min_node);
        for (int i=0; i<8; i=i+1) begin
          if (!visited_w2[i] && adj_matrix[min_node][i] != 0) begin
            dist_w2[i] <= min(dist_w2[i], dist_w2[min_node] + adj_matrix[min_node][i]);
          end
        end
        cycle_count <= cycle_count + 1;
      end

      MATCH_DELIVERIES: begin
        if (delivery_count < num_deliveries) begin
          min_dist = 8'hFF;
          employee_idx = 3'h0;
          target = clients[delivery_count];
          for (int j=0; j<8; j=j+1) begin
            if (!used_employees[j]) begin
              if ((dist_w1[employees[j]] + dist_w1[target]) <
                  (dist_w2[employees[j]] + dist_w2[target])) begin
                if ((dist_w1[employees[j]] + dist_w1[target]) < min_dist) begin
                  min_dist = dist_w1[employees[j]] + dist_w1[target];
                  employee_idx = j;
                end
              end else begin
                if ((dist_w2[employees[j]] + dist_w2[target]) < min_dist) begin
                  min_dist = dist_w2[employees[j]] + dist_w2[target];
                  employee_idx = j;
                end
              end
            end
          end
          used_employees <= used_employees | (8'h01 << employee_idx);
          acc_distance <= acc_distance + min_dist;
          delivery_count <= delivery_count + 1;
        end
      end

      DONE: begin
        total_distance <= acc_distance;
        done <= 1'b1;
      end
    endcase
  end
end

always_comb begin
  next_state = current_state;
  case (current_state)
    IDLE: next_state = start ? COMPUTE_W1 : IDLE;
    COMPUTE_W1: next_state = (cycle_count < 8) ? COMPUTE_W1 : COMPUTE_W2;
    COMPUTE_W2: next_state = (cycle_count < 16) ? COMPUTE_W2 : MATCH_DELIVERIES;
    MATCH_DELIVERIES: begin
      if (delivery_count >= num_deliveries)
        next_state = DONE;
      else
        next_state = MATCH_DELIVERIES;
    end
    DONE: next_state = IDLE;
    default: next_state = IDLE;
  endcase
end

endmodule