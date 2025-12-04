module train_route_optimizer(input clk, input rst_n, input start, input [3:0] num_cities, input [15:0] adj_matrix, output reg [1:0] min_flights, output reg [3:0] airports, output reg done);
  parameter IDLE = 2'b00;
  parameter PROCESSING = 2'b01;
  parameter DONE = 2'b10;
  reg [1:0] state;
  reg [1:0] counter;
  
  reg [2:0] dist [0:3];
  reg [3:0] paths [0:3];
  wire [3:0] adj_row [0:3];
  
  assign adj_row[0] = adj_matrix[3:0];
  assign adj_row[1] = adj_matrix[7:4];
  assign adj_row[2] = adj_matrix[11:8];
  assign adj_row[3] = adj_matrix[15:12];
  
  integer i, j;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      min_flights <= 0;
      airports <= 0;
      counter <= 0;
      for (i=0; i<4; i=i+1) begin
        dist[i] <= 3'b0;
        paths[i] <= 4'b0;
      end
    end else begin
      case(state)
        IDLE: begin
          done <= 0;
          if (start) begin
            for (i=0; i<4; i=i+1) begin
              dist[i] <= (i < num_cities) ? 3'b0 : 3'b0;
              paths[i] <= (i < num_cities) ? (1 << i) : 4'b0;
            end
            counter <= 0;
            state <= PROCESSING;
          end
        end
        
        PROCESSING: begin
          if (counter == 2) begin
            state <= DONE;
          end else begin
            counter <= counter + 1;
          end
          for (j=0; j<4; j=j+1) begin
            if (j < num_cities) begin
              dist[j] <= dist[j];
              for (i=0; i<4; i=i+1) begin
                if (i < num_cities && adj_row[i][j] && (i != j)) begin
                  if ((dist[i] + 1) > dist[j]) begin
                    dist[j] <= dist[i] + 1;
                    paths[j] <= paths[i] | (1 << j);
                  end else if ((dist[i] + 1) == dist[j]) begin
                    paths[j] <= paths[j] | paths[i] | (1 << j);
                  end
                end
              end
            end
          end
        end
        
        DONE: begin
          state <= IDLE;
          done <= 1;
          begin : output_calculation
            reg [2:0] max_dist;
            reg [3:0] visitable;
            max_dist = 0;
            visitable = 0;
            for (i=0; i<4; i=i+1) begin
              if (i < num_cities && dist[i] > max_dist) max_dist = dist[i];
            end
            for (i=0; i<4; i=i+1) begin
              if (i < num_cities && dist[i] == max_dist) visitable = visitable | paths[i];
            end
            min_flights <= num_cities - max_dist - 1;
            airports <= visitable;
          end
        end
      endcase
    end
  end
endmodule