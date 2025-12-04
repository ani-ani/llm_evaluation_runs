module stellar_body_counter(
  input clk,
  input rst_n,
  input start,
  input [3:0] grid_row,
  input [3:0] grid_col,
  input [15:0] pixel_value,
  input pixel_valid,
  output reg [7:0] star_count,
  output reg done
);

  // Grid memory
  reg [15:0] grid[0:15][0:15];
  
  // Label memory
  reg [7:0] label[0:15][0:15];
  
  // Disjoint set data structure
  reg [7:0] parent[0:255];
  
  // FSM states
  enum reg [2:0] {
    IDLE,
    LOAD,
    PROCESS,
    RESOLVE,
    COUNT,
    DONE
  } state, next_state;
  
  // Counter registers
  reg [8:0] cycle_count;
  reg [3:0] row_ptr, col_ptr;
  reg [7:0] max_label;
  
  // Helper signals
  reg [7:0] current_label;
  reg [7:0] left_label, top_label;
  reg [7:0] min_neighbor;
  reg [7:0] root_i;
  
  integer i, j;
  
  // FSM
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_count <= 0;
    end else begin
      state <= next_state;
      cycle_count <= cycle_count + 1;
    end
  end
  
  // Control signals
  always_comb begin
    next_state = state;
    case (state)
      IDLE: if (pixel_valid) next_state = LOAD;
      LOAD: if (!pixel_valid) next_state = IDLE;
              else if (cycle_count == 255) next_state = idle_after_load;
            else if (!pixel_valid && start) next_state = PROCESS;
      idle_after_load: if (start) next_state = PROCESS;
      PROCESS: if (cycle_count >= 256) next_state = RESOLVE;
      RESOLVE: if (cycle_count == 256 + 10) next_state = COUNT;
      COUNT: if (cycle_count == 256 + 10 + 256) next_state = DONE;
      DONE: next_state = DONE;
    endcase
    done = (state == DONE);
  end
  
  // Grid loading
  always_ff @(posedge clk) begin
    if (pixel_valid && state == LOAD) begin
      grid[grid_row][grid_col] <= pixel_value;
    end
  end
  
  // PROCESS state operations
  always_ff @(posedge clk) begin
    case (state)
      PROCESS: begin
        // Clear labels and parents
        if (cycle_count == 0) begin
          current_label <= 1;
          for (i = 0; i < 16; i++) begin
            for (j = 0; j < 16; j++) begin
              label[i][j] <= 0;
            end
          end
          for (i = 0; i < 256; i++) begin
            parent[i] <= i;
          end
          row_ptr <= 0;
          col_ptr <= 0;
        end
        else begin
          // Calculate coordinates
          if (col_ptr == 15) begin
            col_ptr <= 0;
            if (row_ptr < 15) row_ptr <= row_ptr + 1;
            else row_ptr <= 0;
          end else begin
            col_ptr <= col_ptr + 1;
          end
          
          // Process current pixel
          if (grid[row_ptr][col_ptr] >= 16'h8000) begin
            left_label = (col_ptr != 0) ? label[row_ptr][col_ptr-1] : 0;
            top_label = (row_ptr != 0) ? label[row_ptr-1][col_ptr] : 0;
            
            // Find minimum valid neighbor label
            min_neighbor = 255;
            if (left_label != 0 && left_label < min_neighbor) 
              min_neighbor = left_label;
            if (top_label != 0 && top_label < min_neighbor) 
              min_neighbor = top_label;
            
            // Assign new label if no neighbors
            if (min_neighbor == 255) begin
              label[row_ptr][col_ptr] <= current_label;
              parent[current_label] <= current_label;
              current_label <= current_label + 1;
            end else begin
              // Union other labels with min neighbor
              if (left_label != 0 && left_label != min_neighbor) 
                parent[find_root(left_label)] <= find_root(min_neighbor);
              if (top_label != 0 && top_label != min_neighbor) 
                parent[find_root(top_label)] <= find_root(min_neighbor);
              label[row_ptr][col_ptr] <= min_neighbor;
            end
          end
        end
      end
      
      RESOLVE: begin
        // Path compression (2 iterations) Run in parallel for all entries
        if (cycle_count == 256) max_label <= current_label - 1;
        for (int k = 0; k < 256; k++) begin
          if (k <= max_label) begin
            parent[k] <= find_root(parent[k]);
          end
        end
      end
      
      COUNT: begin
        if (cycle_count == 256 + 10) begin
          star_count <= 0;
        end else begin
          // Count root parents
          root_i = find_root(parent[row_ptr]);
          if (root_i == row_ptr && row_ptr != 0) begin
            star_count <= star_count + 1;
          end
          if (row_ptr < max_label) row_ptr <= row_ptr + 1;
        end
      end
    endcase
  end

  // Recursive root finder (function)
  function automatic [7:0] find_root(input [7:0] x);
    if (parent[x] != x) begin
      find_root = find_root(parent[x]);
    end else begin
      find_root = x;
    end
  endfunction

endmodule