module chile_shortest_path (
input clk,
input rst_n, // active low
input start,
input [7:0] valid_nodes,
input [15:0] y_coords [0:7],
input [15:0] d_mins [0:7],
input [15:0] r_times [0:7],
output reg [15:0] dist [0:7],
output reg done
);

reg [2:0] state, iteration_count;
reg [7:0] valid_nodes_reg;
reg [7:0] visited;
reg [2:0] current_node;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= 3'd0;
      iteration_count <= 3'd0;
      valid_nodes_reg <= 8'd0;
      visited <= 8'd0;
      current_node <= 3'd0;
      dist[0] <= 16'd0;
      dist[1] <= 16'd0xFFFF;
      dist[2] <= 16'd0xFFFF;
      dist[3] <= 16'd0xFFFF;
      dist[4] <= 16'd0xFFFF;
      dist[5] <= 16'd0xFFFF;
      dist[6] <= 16'd0xFFFF;
      dist[7] <= 16'd0xFFFF;
      done <= 1'b0;
   end else begin
      case (state)
         3'd0: begin
            if (start) begin
               valid_nodes_reg <= valid_nodes;
               visited <= 8'd0;
               current_node <= 3'd0;
               dist[0] <= 16'd0;
               dist[1] <= 16'd0xFFFF;
               dist[2] <= 16'd0xFFFF;
               dist[3] <= 16'd0xFFFF;
               dist[4] <= 16'd0xFFFF;
               dist[5] <= 16'd0xFFFF;
               dist[6] <= 16'd0xFFFF;
               dist[7] <= 16'd0xFFFF;
               state <= 3'd1;
               iteration_count <= 3'd0;
               done <= 1'b0;
            end else begin
               state <= 3'd0;
            end
         end

         3'd1: begin
            wire [15:0] min_dist = 16'd100000;
wire [2:0] min_node = 3'd8;

if (!visited[0] && dist[0] != 16'd0xFFFF) if (dist[0] < min_dist) begin min_dist = dist[0]; min_node = 3'd0; end
if (!visited[1] && dist[1] != 16'd0xFFFF) if (dist[1] < min_dist) begin min_dist = dist[1]; min_node = 3'd1; end
if (!visited[2] && dist[2] != 16'd0xFFFF) if (dist[2] < min_dist) begin min_dist = dist[2]; min_node = 3'd2; end
if (!visited[3] && dist[3] != 16'd0xFFFF) if (dist[3] < min_dist) begin min_dist = dist[3]; min_node = 3'd3; end
if (!visited[4] && dist[4] != 16'd0xFFFF) if (dist[4] < min_dist) begin min_dist = dist[4]; min_node = 3'd4; end
if (!visited[5] && dist[5] != 16'd0xFFFF) if (dist[5] < min_dist) begin min_dist = dist[5]; min_node = 3'd5; end
if (!visited[6] && dist[6] != 16'd0xFFFF) if (dist[6] < min_dist) begin min_dist = dist[6]; min_node = 3'd6; end
if (!visited[7] && dist[7] != 16'd0xFFFF) if (dist[7] < min_dist) begin min_dist = dist[7]; min_node = 3'd7; end

if (min_node < 3'd8) begin
   current_node <= min_node;
   visited[min_node] <= 1'b1;
   state <= 3'd2;
end else begin
   if (iteration_count < 3'd8) state <= 3'd3;
   else begin done <= 1'b1; state <= 3'd4; end
end

end

3'd2: begin
   int u = current_node;

if (valid_nodes_reg[0] && (y_coords[0] >= y_coords[u] ? y_coords[0]-y_coords[u] : y_coords[u]-y_coords[0]) >= d_mins[u]) begin
   int delta = y_coords[0] >= y_coords[u] ? y_coords[0]-y_coords[u] : y_coords[u]-y_coords[0];
   int new_dist = dist[u] + r_times[u] + delta;
   if (new_dist < dist[0]) dist[0] <= new_dist;
end

if (valid_nodes_reg[1] && (y_coords[1] >= y_coords[u] ? y_coords[1]-y_coords[u] : y_coords[u]-y_coords[1]) >= d_mins[u]) begin
   int delta = y_coords[1] >= y_coords[u] ? y_coords[1]-y_coords[u] : y_coords[u]-y_coords[1];
   int new_dist = dist[u] + r_times[u] + delta;
   if (new_dist < dist[1]) dist[1] <= new_dist;
end

if (valid_nodes_reg[2] && (y_coords[2] >= y_coords[u] ? y_coords[2]-y_coords[u] : y_coords[u]-y_coords[2]) >= d_mins[u]) begin
   int delta = y_coords[2] >= y_coords[u] ? y_coords[2]-y_coords[u] : y_coords[u]-y_coords[2];
   int new_dist = dist[u] + r_times[u] + delta;
   if (new_dist < dist[2]) dist[2] <= new_dist;
end

if (valid_nodes_reg[3] && (y_coords[3] >= y_coords[u] ? y_coords[3]-y_coords[u] : y_coords[u]-y_coords[3]) >= d_mins[u]) begin
   int delta = y_coords[3] >= y_coords[u] ? y_coords[3]-y_coords[u] : y_coords[u]-y_coords[3];
   int new_dist = dist[u] + r_times[u] + delta;
   if (new_dist < dist[3]) dist[3] <= new_dist;
end

if (valid_nodes_reg[4] && (y_coords[4] >= y_coords[u] ? y_coords[4]-y_coords[u] : y_coords[u]-y_coords[4]) >= d_mins[u]) begin
   int delta = y_coords[4] >= y_coords[u] ? y_coords[4]-y_coords[u] : y_coords[u]-y_coords[4];
   int new_dist = dist[u] + r_times[u] + delta;
   if (new_dist < dist[4]) dist[4] <= new_dist;
end

if (valid_nodes_reg[5] && (y_coords[5] >= y_coords[u] ? y_coords[5]-y_coords[u] : y_coords[u]-y_coords[5]) >= d_mins[u]) begin
   int delta = y_coords[5] >= y_coords[u] ? y_coords[5]-y_coords[u] : y_coords[u]-y_coords[5];
   int new_dist = dist[u] + r_times[u] + delta;
   if (new_dist < dist[5]) dist[5] <= new_dist;
end

if (valid_nodes_reg[6] && (y_coords[6] >= y_coords[u] ? y_coords[6]-y_coords[u] : y_coords[u]-y_coords[6]) >= d_mins[u]) begin
   int delta = y_coords[6] >= y_coords[u] ? y_coords[6]-y_coords[u] : y_coords[u]-y_coords[6];
   int new_dist = dist[u] + r_times[u] + delta;
   if (new_dist < dist[6]) dist[6] <= new_dist;
end

if (valid_nodes_reg[7] && (y_coords[7] >= y_coords[u] ? y_coords[7]-y_coords[u] : y_coords[u]-y_coords[7]) >= d_mins[u]) begin
   int delta = y_coords[7] >= y_coords[u] ? y_coords[7]-y_coords[u] : y_coords[u]-y_coords[7];
   int new_dist = dist[u] + r_times[u] + delta;
   if (new_dist < dist[7]) dist[7] <= new_dist;
end

state <= 3'd3;
end

3'd3: begin
   iteration_count <= iteration_count + 3'd1;
   if (iteration_count >= 3'd8) begin done <= 1'b1; state <= 3'd4; end
   else if (done == 1'b0) state <= 3'd1;
   else state <= 3'd4;
end

3'd4: state <= 3'd4;
endcase
end
endmodule