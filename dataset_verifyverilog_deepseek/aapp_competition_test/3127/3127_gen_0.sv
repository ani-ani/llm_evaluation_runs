module network_switch_analyzer (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] m,
  input [2:0] edges [15:0][2:0],
  input [15:0] len_low [15:0],
  output reg [7:0] unused_mask,
  output reg done
);

localparam MAX_DIST = 24'hFFFFFF;
localparam IDLE = 4'd0;
localparam BUILD_ADJ = 4'd1;
localparam DIJKSTRA_INIT_FORWARD = 4'd2;
localparam DIJKSTRA_FIND_MIN_FORWARD = 4'd3;
localparam DIJKSTRA_UPDATE_FORWARD = 4'd4;
localparam DIJKSTRA_INIT_REVERSE = 4'd5;
localparam DIJKSTRA_FIND_MIN_REVERSE = 4'd6;
localparam DIJKSTRA_UPDATE_REVERSE = 4'd7;
localparam CHECK = 4'd8;
localparam DONE = 4'd9;

reg [3:0] state;
reg [4:0] counter;
reg [2:0] dijkstra_iter;
reg [2:0] current_node;
reg [7:0] visited1, visited2;
reg [23:0] adj_matrix [0:7][0:7];
reg [23:0] rev_matrix [0:7][0:7];
reg [23:0] dist1 [0:7];
reg [23:0] dist2 [0:7];
reg [2:0] stored_n;
reg [2:0] stored_m;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 0;
    counter <= 0;
    unused_mask <= 8'h00;
    stored_n <= 0;
    stored_m <= 0;
    for (int i=0; i<8; i++) begin
      for (int j=0; j<8; j++) begin
        adj_matrix[i][j] <= MAX_DIST;
        rev_matrix[i][j] <= MAX_DIST;
      end
    end
    for (int i=0; i<8; i++) begin
      dist1[i] <= MAX_DIST;
      dist2[i] <= MAX_DIST;
    end
    visited1 <= 8'h00;
    visited2 <= 8'h00;
    dijkstra_iter <= 0;
    current_node <= 0;
  end else begin
    case (state)
      IDLE: begin
        done <= 0;
        if (start) begin
          stored_n <= n;
          stored_m <= m;
          for (int i=0; i<8; i++) begin
            for (int j=0; j<8; j++) begin
              adj_matrix[i][j] <= MAX_DIST;
              rev_matrix[i][j] <= MAX_DIST;
            end
          end
          counter <= 0;
          state <= BUILD_ADJ;
        end
      end
      BUILD_ADJ: begin
        if (counter < m) begin
          automatic logic [2:0] a = edges[counter][0] - 3'd1;
          automatic logic [2:0] b = edges[counter][1] - 3'd1;
          automatic logic [23:0] len = {edges[counter][2], len_low[counter]};
          adj_matrix[a][b] <= len;
          rev_matrix[b][a] <= len;
          counter <= counter + 1;
        end else begin
          state <= DIJKSTRA_INIT_FORWARD;
        end
      end
      DIJKSTRA_INIT_FORWARD: begin
        for (int i=0; i<8; i++) dist1[i] <= MAX_DIST;
        dist1[0] <= 0;
        visited1 <= 8'h00;
        dijkstra_iter <= 0;
        state <= DIJKSTRA_FIND_MIN_FORWARD;
      end
      DIJKSTRA_FIND_MIN_FORWARD: begin
        automatic logic [23:0] min_dist = MAX_DIST;
        automatic logic [2:0] min_node = 0;
        automatic logic found = 0;
        for (int i=0; i<8; i++) begin
          if (!visited1[i] && (dist1[i] < min_dist)) begin
            min_dist = dist1[i];
            min_node = i;
            found = 1;
          end
        end
        if (found) begin
          visited1[min_node] <= 1'b1;
          current_node <= min_node;
          state <= DIJKSTRA_UPDATE_FORWARD;
        end else begin
          dijkstra_iter <= 0;
          state <= DIJKSTRA_INIT_REVERSE;
        end
      end
      DIJKSTRA_UPDATE_FORWARD: begin
        for (int j=0; j<8; j++) begin
          automatic logic [23:0] new_dist;
          if (current_node != j && adj_matrix[current_node][j] != MAX_DIST) begin
            new_dist = dist1[current_node] + adj_matrix[current_node][j];
            if (new_dist < dist1[j]) dist1[j] <= new_dist;
          end
        end
        dijkstra_iter <= dijkstra_iter + 1;
        state <= (dijkstra_iter == 3'd7) ? DIJKSTRA_INIT_REVERSE : DIJKSTRA_FIND_MIN_FORWARD;
      end
      DIJKSTRA_INIT_REVERSE: begin
        for (int i=0; i<8; i++) dist2[i] <= MAX_DIST;
        dist2[stored_n-3'd1] <= 0;
        visited2 <= 8'h00;
        dijkstra_iter <= 0;
        state <= DIJKSTRA_FIND_MIN_REVERSE;
      end
      DIJKSTRA_FIND_MIN_REVERSE: begin
        automatic logic [23:0] min_dist = MAX_DIST;
        automatic logic [2:0] min_node = 0;
        automatic logic found = 0;
        for (int i=0; i<8; i++) begin
          if (!visited2[i] && (dist2[i] < min_dist)) begin
            min_dist = dist2[i];
            min_node = i;
            found = 1;
          end
        end
        if (found) begin
          visited2[min_node] <= 1'b1;
          current_node <= min_node;
          state <= DIJKSTRA_UPDATE_REVERSE;
        end else begin
          state <= CHECK;
        end
      end
      DIJKSTRA_UPDATE_REVERSE: begin
        for (int j=0; j<8; j++) begin
          automatic logic [23:0] new_dist;
          if (current_node != j && rev_matrix[current_node][j] != MAX_DIST) begin
            new_dist = dist2[current_node] + rev_matrix[current_node][j];
            if (new_dist < dist2[j]) dist2[j] <= new_dist;
          end
        end
        dijkstra_iter <= dijkstra_iter + 1;
        state <= (dijkstra_iter == 3'd7) ? CHECK : DIJKSTRA_FIND_MIN_REVERSE;
      end
      CHECK: begin
        for (int i=0; i<8; i++) begin
          if (i >= stored_n) unused_mask[i] <= 1'b1;
          else if (i == 0 || i == stored_n-3'd1) unused_mask[i] <= 1'b0;
          else unused_mask[i] <= ( (dist1[i] + dist2[i]) != dist1[stored_n-3'd1] );
        end
        state <= DONE;
      end
      DONE: begin
        done <= 1'b1;
        if (!start) state <= IDLE;
      end
      default: state <= IDLE;
    endcase
  end
end

endmodule