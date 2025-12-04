module stellar_body_counter(
  input clk,
  input rst_n,
  input start,
  input [3:0] grid_row,      // 4-bit row address (0-15)
  input [3:0] grid_col,      // 4-bit column address (0-15)
  input [15:0] pixel_value,  // 16-bit pixel value
  input pixel_valid,         // High when pixel_value valid
  output reg [7:0] star_count, // Number of stellar bodies found (0-255)
  output reg done            // High when computation complete
);

  // State machine states
  typedef enum logic [1:0] {
    IDLE = 2'b00,
    LOAD = 2'b01,
    PROCESS_FIRST = 2'b10,
    PROCESS_SECOND = 2'b11,
    DONE = 2'b100
  } state_t;
  
  state_t current_state, next_state;
  
  // Grid storage: 16x16 grid of 16-bit pixels
  reg [15:0] grid_mem [0:255];  // 256 x 16-bit memory
  
  // Component labeling storage
  reg [7:0] label_mem [0:255];   // 256 x 8-bit for labels
  reg [7:0] parent [0:255];      // 256 x 8-bit for union-find
  reg [7:0] current_label;       // Current label counter
  
  // Counters
  reg [7:0] load_count;          // Count loaded pixels
  reg [7:0] process_count;       // Count processed pixels
  
  // visited array for distinct label counting
  reg [255:0] visited_labels;    // 256-bit visited array
  
  // Find function (iterative path following without compression)
  function [7:0] find;
    input [7:0] x;
    begin
      while (parent[x] != x) begin
        x = parent[x];
      end
      find = x;
    end
  endfunction
  
  // State machine sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      star_count <= 0;
      load_count <= 0;
      process_count <= 0;
      current_label <= 0;
      visited_labels <= 0;
    end else begin
      current_state <= next_state;
      
      case (current_state)
        IDLE: begin
          done <= 0;
          star_count <= 0;
          load_count <= 0;
          process_count <= 0;
          current_label <= 0;
          visited_labels <= 0;
        end
        
        LOAD: begin
          if (pixel_valid) begin
            grid_mem[load_count] <= pixel_value;
            load_count <= load_count + 1;
          end
        end
        
        PROCESS_FIRST: begin
          // First pass - assign provisional labels
          if (process_count < 256) begin
            if (grid_mem[process_count] >= 16'h8000) begin // Bright pixel
              integer row, col;
              reg [7:0] top, left;
              reg [7:0] a, b;
              
              row = process_count / 16;
              col = process_count % 16;
              
              // Get top and left neighbor labels
              if (row == 0) top = 0;
              else top = label_mem[(row-1)*16 + col];
              
              if (col == 0) left = 0;
              else left = label_mem[row*16 + col-1];
              
              if (top == 0 && left == 0) begin
                // New component
                current_label = current_label + 1;
                label_mem[process_count] = current_label;
                parent[current_label] = current_label;
              end else if (top != 0 && left == 0) begin
                // Use top label
                a = find(top);
                label_mem[process_count] = a;
              end else if (top == 0 && left != 0) begin
                // Use left label
                b = find(left);
                label_mem[process_count] = b;
              end else begin
                // Both top and left exist - may need union
                a = find(top);
                b = find(left);
                if (a != b) begin
                  parent[a] = b; // Union by setting parent
                end
                label_mem[process_count] = b;
              end
            end else begin
              label_mem[process_count] = 0; // Dark pixel
            end
            process_count <= process_count + 1;
          end
        end
        
        PROCESS_SECOND: begin
          // Second pass - count distinct components
          if (process_count < 256) begin
            if (label_mem[process_count] != 0) begin
              reg [7:0] root;
              root = find(label_mem[process_count]);
              if (!visited_labels[root]) begin
                visited_labels[root] = 1;
                star_count <= star_count + 1;
              end
            end
            process_count <= process_count + 1;
          end else begin
            done <= 1;
          end
        end
        
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end
  
  // State machine next state logic
  always @(*) begin
    case (current_state)
      IDLE: begin
        if (start) next_state = LOAD;
        else next_state = IDLE;
      end
      
      LOAD: begin
        if (load_count >= 256) begin
          // Grid fully loaded, start processing
          process_count = 0;
          next_state = PROCESS_FIRST;
        end else begin
          next_state = LOAD;
        end
      end
      
      PROCESS_FIRST: begin
        if (process_count >= 256) begin
          // First pass complete, start second pass
          process_count = 0;
          next_state = PROCESS_SECOND;
        end else begin
          next_state = PROCESS_FIRST;
        end
      end
      
      PROCESS_SECOND: begin
        if (process_count >= 256) begin
          // Second pass complete
          next_state = DONE;
        end else begin
          next_state = PROCESS_SECOND;
        end
      end
      
      DONE: begin
        if (start) next_state = LOAD; // Allow restart
        else next_state = DONE;
      end
      
      default: next_state = IDLE;
    endcase
  end
  
endmodule
