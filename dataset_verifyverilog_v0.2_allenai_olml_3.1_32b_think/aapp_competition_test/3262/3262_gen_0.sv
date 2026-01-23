module min_trucks_solver (
input clk,
input rst_n,
input start,
input [2:0] num_nodes,
input [2:0] num_edges,
input [2:0] num_clients,
input [2:0] client_locs [3:0],
input [2:0] edge_u [7:0],
input [2:0] edge_v [7:0],
input [3:0] edge_w [7:0],
output reg [2:0] min_trucks,
output reg done
);

// Registers
reg [2:0] state;
reg [6:0] dist [7:0];
reg [2:0] iteration_counter;
reg [2:0] min_trucks_reg;
reg done_reg;
reg [6:0] next_dist [7:0];
reg [7:0] client_mask;
reg [6:0] delay_counter;
reg [2:0] u, v;
reg [3:0] w;

// State definitions
localparam IDLE = 3'd0;
localparam BUILD_DIST = 3'd1;
localparam BUILD_DAG = 3'd2;
localparam COMPUTE_RESULT = 3'd3;
localparam DONE = 3'd4;

always_ff @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      dist[7:0] <= 8'b0;
      dist[0] <= 7'b0; // node0 distance 0
      dist[1] <= 4'd16;
      dist[2] <= 4'd16;
      dist[3] <= 4'd16;
      dist[4] <= 4'd16;
      dist[5] <= 4'd16;
      dist[6] <= 4'd16;
      dist[7] <= 4'd16;
      iteration_counter <= 3'd0;
      min_trucks_reg <= 3'd0;
      done_reg <= 1'b0;
      client_mask <= 8'b0;
      next_dist[7:0] <= 8'b0;
      delay_counter <= 6'd0;
   end else begin
      if (state == IDLE) begin
         if (start) begin
            state <= BUILD_DIST;
            iteration_counter <= 3'd0;
         end
      end else if (state == BUILD_DIST) begin
         iteration_counter <= iteration_counter + 3'd1;
         if (iteration_counter == 8) begin
            state <= BUILD_DAG;
            iteration_counter <= 3'd0;
         end
         // Update distances
         dist[7:0] <= next_dist[7:0];
      end else if (state == BUILD_DAG) begin
         // Transition to COMPUTE_RESULT with delay
         state <= COMPUTE_RESULT;
         delay_counter <= 6'd56; // 56 cycles delay
         iteration_counter <= 3'd0;
      end else if (state == COMPUTE_RESULT) begin
         if (delay_counter == 0) begin
            min_trucks_reg <= num_clients;
            state <= DONE;
         end else begin
            delay_counter <= delay_counter - 3'd1;
         end
      end else if (state == DONE) begin
         // Stay in done
      end
   end
end

// Combinational next_dist
always_comb begin
   // Initialize next_dist to current dist
   next_dist[0] = dist[0];
   next_dist[1] = dist[1];
   next_dist[2] = dist[2];
   next_dist[3] = dist[3];
   next_dist[4] = dist[4];
   next_dist[5] = dist[5];
   next_dist[6] = dist[6];
   next_dist[7] = dist[7];
   // Process each edge
   // Edge 0
   if (num_edges > 0) begin
      u = edge_u[0];
      v = edge_v[0];
      w = edge_w[0];
      candidate = dist[u] + w;
      if (candidate < next_dist[v]) next_dist[v] = candidate;
   end
   // Edge 1
   if (num_edges > 1) begin
      u = edge_u[1];
      v = edge_v[1];
      w = edge_w[1];
      candidate = dist[u] + w;
      if (candidate < next_dist[v]) next_dist[v] = candidate;
   end
   // Edge 2
   if (num_edges > 2) begin
      u = edge_u[2];
      v = edge_v[2];
      w = edge_w[2];
      candidate = dist[u] + w;
      if (candidate < next_dist[v]) next_dist[v] = candidate;
   end
   // Edge 3
   if (num_edges > 3) begin
      u = edge_u[3];
      v = edge_v[3];
      w = edge_w[3];
      candidate = dist[u] + w;
      if (candidate < next_dist[v]) next_dist[v] = candidate;
   end
   // Edge 4
   if (num_edges > 4) begin
      u = edge_u[4];
      v = edge_v[4];
      w = edge_w[4];
      candidate = dist[u] + w;
      if (candidate < next_dist[v]) next_dist[v] = candidate;
   end
   // Edge 5
   if (num_edges > 5) begin
      u = edge_u[5];
      v = edge_v[5];
      w = edge_w[5];
      candidate = dist[u] + w;
      if (candidate < next_dist[v]) next_dist[v] = candidate;
   end
   // Edge 6
   if (num_edges > 6) begin
      u = edge_u[6];
      v = edge_v[6];
      w = edge_w[6];
      candidate = dist[u] + w;
      if (candidate < next_dist[v]) next_dist[v] = candidate;
   end
   // Edge 7
   if (num_edges > 7) begin
      u = edge_u[7];
      v = edge_v[7];
      w = edge_w[7];
      candidate = dist[u] + w;
      if (candidate < next_dist[v]) next_dist[v] = candidate;
   end
end

// Combinational client_mask
always_comb begin
   client_mask = 8'b0;
   if (num_clients > 0) begin
      client_mask[client_locs[0]] = 1;
   end
   if (num_clients > 1) begin
      client_mask[client_locs[1]] = 1;
   end
   if (num_clients > 2) begin
      client_mask[client_locs[2]] = 1;
   end
   if (num_clients > 3) begin
      client_mask[client_locs[3]] = 1;
   end
end

// Output assignments
assign min_trucks = min_trucks_reg;
assign done = done_reg;

endmodule