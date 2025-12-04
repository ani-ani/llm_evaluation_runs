module pizza_delivery_optimizer(
  input clk,
  input rst_n,
  input start,
  input [1:0] node_count,
  input [2:0] edge_count,
  input [3:0][1:0] edge_src,
  input [3:0][1:0] edge_dest,
  input [3:0][7:0] edge_weight,
  input [1:0] order_count,
  input [2:0][7:0] order_spawn,
  input [2:0][1:0] order_loc,
  input [2:0][7:0] order_ready,
  output reg [7:0] max_wait,
  output reg done
);

  typedef enum {
    IDLE,
    LOAD_DATA,
    COMPUTE_GRAPH,
    PROCESS_ORDERS,
    DONE
  } state_t;

  reg [2:0] processed;
  state_t current_state, next_state;
  reg [3:0][3:0][7:0] dist_matrix;
  reg [1:0] current_location;
  reg [7:0] current_time;
  reg [7:0] max_wait_i;
  reg done_i;
  
  // Floyd-Warshall counters
  reg [1:0] k, i, j;
  reg fw_initialized;
  
  // Order processing
  reg [1:0] selected_order;
  reg [7:0] travel_time;
  
  // Registered inputs
  reg [1:0] node_count_r;
  reg [2:0] edge_count_r;
  reg [3:0][1:0] edge_src_r, edge_dest_r;
  reg [3:0][7:0] edge_weight_r;
  reg [1:0] order_count_r;
  reg [2:0][7:0] order_spawn_r;
  reg [2:0][1:0] order_loc_r;
  reg [2:0][7:0] order_ready_r;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      max_wait <= 8'h00;
      done <= 1'b0;
      processed <= 3'b000;
      current_location <= 2'b00;
      current_time <= 8'h00;
      max_wait_i <= 8'h00;
      done_i <= 1'b0;
      fw_initialized <= 1'b0;
      k <= 2'b00;
      i <= 2'b00;
      j <= 2'b00;
      selected_order <= 2'b00;
      travel_time <= 8'h00;
      
      node_count_r <= 2'b00;
      edge_count_r <= 3'b000;
      edge_src_r <= '0;
      edge_dest_r <= '0;
      edge_weight_r <= '0;
      order_count_r <= 2'b00;
      order_spawn_r <= '0;
      order_loc_r <= '0;
      order_ready_r <= '0;
    end else begin
      current_state <= next_state;
      max_wait <= max_wait_i;
      done <= done_i;
    
      case (current_state)
        IDLE: begin
          done_i <= 1'b0;
          if (start) begin
            node_count_r <= node_count;
            edge_count_r <= edge_count;
            edge_src_r <= edge_src;
            edge_dest_r <= edge_dest;
            edge_weight_r <= edge_weight;
            order_count_r <= order_count;
            order_spawn_r <= order_spawn;
            order_loc_r <= order_loc;
            order_ready_r <= order_ready;
            next_state <= LOAD_DATA;
          end else begin
            next_state <= IDLE;
          end
        end
        
        LOAD_DATA: begin
          // Initialize distance matrix
          if (!fw_initialized) begin
            for (int m = 0; m < 4; m++) begin
              for (int n = 0; n < 4; n++) begin
                dist_matrix[m][n] <= (m == n) ? 8'h00 : 8'hFF;
              end
            end
            // Load edges
            for (int e = 0; e < edge_count_r; e++) begin
              dist_matrix[edge_src_r[e]][edge_dest_r[e]] <= edge_weight_r[e];
            end
            fw_initialized <= 1'b1;
            next_state <= LOAD_DATA;
          end else begin
            fw_initialized <= 1'b0;
            k <= 2'b00;
            i <= 2'b00;
            j <= 2'b00;
            next_state <= COMPUTE_GRAPH;
          end
        end
        
        COMPUTE_GRAPH: begin
          // Floyd-Warshall algorithm
          if (k < node_count_r) begin
            if (i < node_count_r) begin
              if (j < node_count_r) begin
                if (dist_matrix[i][k] + dist_matrix[k][j] < dist_matrix[i][j]) begin
                  dist_matrix[i][j] <= dist_matrix[i][k] + dist_matrix[k][j];
                end
                j <= j + 1;
              end else begin
                j <= 2'b00;
                i <= i + 1;
              end
            end else begin
              i <= 2'b00;
              j <= 2'b00;
              k <= k + 1;
            end
            next_state <= COMPUTE_GRAPH;
          end else begin
            // Initialize order processing
            current_location <= 2'b00;
            current_time <= 8'h00;
            max_wait_i <= 8'h00;
            processed <= 3'b000;
            selected_order <= 2'b00;
            travel_time <= 8'h00;
            next_state <= PROCESS_ORDERS;
          end
        end
        
        PROCESS_ORDERS: begin
          if (processed < order_count_r) begin
            // Find next unprocessed order with smallest order_ready
            reg [1:0] min_idx;
            reg [7:0] min_val;
            min_val = 8'hFF;
            min_idx = 2'd3;
            
            for (int o = 0; o < 3; o++) begin
              if (!processed[o] && (order_ready_r[o] < min_val || 
                 (order_ready_r[o] == min_val && o < min_idx))) begin
                min_val = order_ready_r[o];
                min_idx = o;
              end
            end
            
            if (min_idx < 3) begin
              // Calculate travel time
              travel_time <= dist_matrix[current_location][order_loc_r[min_idx]];
              
              // Calculate delivery time
              reg [7:0] delivery_time;
              delivery_time = (current_time > order_ready_r[min_idx]) ? current_time : order_ready_r[min_idx];
              delivery_time = delivery_time + travel_time;
              
              // Calculate wait time
              reg [7:0] wait_time;
              wait_time = delivery_time - order_spawn_r[min_idx];
              
              // Update max wait
              if (wait_time > max_wait_i) begin
                max_wait_i <= wait_time;
              end
              
              // Update state
              current_time <= delivery_time;
              current_location <= order_loc_r[min_idx];
              processed[min_idx] <= 1'b1;
            end
            next_state <= PROCESS_ORDERS;
          end else begin
            done_i <= 1'b1;
            next_state <= DONE;
          end
        end
        
        DONE: begin
          next_state <= DONE;
        end
      endcase
    end
  end

  always_comb begin
    case (current_state)
      IDLE: begin
        // Default assignments
      end
      default: begin
        // Default assignments
      end
    endcase
  end

endmodule