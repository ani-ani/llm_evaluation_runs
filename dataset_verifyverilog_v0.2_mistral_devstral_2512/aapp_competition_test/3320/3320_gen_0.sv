module or_path_calculator (
  input clk,
  input rst_n,
  input start,
  input [3:0] node_count,
  input [3:0] edge_count,
  input [15:0] edges [0:15],
  input [3:0] query_s,
  input [3:0] query_t,
  output reg [15:0] result,
  output reg done
);

  // Constants
  localparam IDLE = 3'b000;
  localparam INIT = 3'b001;
  localparam PROCESSING = 3'b010;
  localparam DONE = 3'b100;

  localparam MAX_NODES = 8;
  localparam INF = 16'hFFFF;

  // State machine
  reg [2:0] state = IDLE;
  reg [2:0] next_state = IDLE;

  // Distance matrix (8x8)
  reg [15:0] dist [0:MAX_NODES-1][0:MAX_NODES-1];

  // Counters
  reg [2:0] k = 0;
  reg [2:0] i = 0;
  reg [2:0] j = 0;
  reg [5:0] delay_counter = 0;

  // Initialize distance matrix
  integer e;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      k <= 0;
      i <= 0;
      j <= 0;
      delay_counter <= 0;
      for (e = 0; e < MAX_NODES; e = e + 1) begin
        for (int f = 0; f < MAX_NODES; f = f + 1) begin
          dist[e][f] <= INF;
        end
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          if (start) begin
            next_state <= INIT;
          end
        end

        INIT: begin
          // Initialize diagonal to 0
          for (e = 0; e < MAX_NODES; e = e + 1) begin
            dist[e][e] <= 0;
          end

          // Initialize direct edges
          for (e = 0; e < edge_count; e = e + 1) begin
            dist[edges[e][15:12]][edges[e][11:8]] <= edges[e][7:0];
          end

          next_state <= PROCESSING;
          k <= 0;
          i <= 0;
          j <= 0;
        end

        PROCESSING: begin
          if (j == MAX_NODES-1) begin
            if (i == MAX_NODES-1) begin
              if (k == MAX_NODES-1) begin
                next_state <= DONE;
                delay_counter <= 0;
              end else begin
                k <= k + 1;
                i <= 0;
                j <= 0;
              end
            end else begin
              i <= i + 1;
              j <= 0;
            end
          end else begin
            j <= j + 1;
          end

          // Update distance matrix
          if (i < node_count && j < node_count && k < node_count) begin
            if (dist[i][k] | dist[k][j] < dist[i][j]) begin
              dist[i][j] <= dist[i][k] | dist[k][j];
            end
          end
        end

        DONE: begin
          if (delay_counter == 50) begin
            done <= 1;
            result <= dist[query_s][query_t];
          end else begin
            delay_counter <= delay_counter + 1;
          end
        end
      endcase
    end
  end

endmodule