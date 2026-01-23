module baltic_drain (
  input clk,
  input rst_n,
  input start,
  input [5:0] device_row,
  input [5:0] device_col,
  input [3:0] altitude_map [8][8],
  output reg [15:0] total_drained,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    INITIALIZE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Water level storage (4-bit signed, same as altitude)
  reg [3:0] water [8][8];

  // Processed cells tracking
  reg processed [8][8];

  // Queue for cells to process (max 64 entries)
  reg [5:0] queue_row [64];
  reg [5:0] queue_col [64];
  reg [5:0] queue_head, queue_tail;
  reg queue_empty, queue_full;

  // Current cell being processed
  reg [5:0] current_row, current_col;

  // Initialize state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      total_drained <= 0;
      done <= 0;
      queue_head <= 0;
      queue_tail <= 0;
      queue_empty <= 1;
      queue_full <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // State transition logic
  always @(*) begin
    case (current_state)
      IDLE: begin
        if (start) next_state = INITIALIZE;
        else next_state = IDLE;
      end
      INITIALIZE: next_state = PROCESSING;
      PROCESSING: begin
        if (queue_empty) next_state = DONE;
        else next_state = PROCESSING;
      end
      DONE: begin
        if (start) next_state = INITIALIZE;
        else next_state = DONE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Initialize water levels and queue
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 8; i++) begin
        for (int j = 0; j < 8; j++) begin
          water[i][j] <= 0;
          processed[i][j] <= 0;
        end
      end
    end else if (current_state == INITIALIZE) begin
      // Initialize water levels
      for (int i = 0; i < 8; i++) begin
        for (int j = 0; j < 8; j++) begin
          water[i][j] <= (altitude_map[i][j][3] == 1) ? 0 : altitude_map[i][j];
          processed[i][j] <= 0;
        end
      end
      
      // Initialize queue with device location
      queue_row[0] <= device_row;
      queue_col[0] <= device_col;
      queue_head <= 0;
      queue_tail <= 1;
      queue_empty <= 0;
      queue_full <= 0;
      total_drained <= 0;
      done <= 0;
    end
  end

  // Process queue
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_row <= 0;
      current_col <= 0;
    end else if (current_state == PROCESSING && !queue_empty) begin
      // Dequeue current cell
      current_row <= queue_row[queue_head];
      current_col <= queue_col[queue_head];
      queue_head <= queue_head + 1;
      
      if (queue_head == queue_tail) begin
        queue_empty <= 1;
      end
      
      // Process current cell
      if (!processed[current_row][current_col] && water[current_row][current_col] > 0) begin
        // Drain current cell
        total_drained <= total_drained + water[current_row][current_col];
        water[current_row][current_col] <= 0;
        processed[current_row][current_col] <= 1;
        
        // Enqueue neighbors
        for (int di = -1; di <= 1; di++) begin
          for (int dj = -1; dj <= 1; dj++) begin
            if (di == 0 && dj == 0) continue; // Skip self
            
            int ni = current_row + di;
            int nj = current_col + dj;
            
            if (ni >= 0 && ni < 8 && nj >= 0 && nj < 8) begin
              if (!processed[ni][nj] && water[ni][nj] > 0 && altitude_map[ni][nj][3] == 1) begin
                // Check if queue is full
                if (!queue_full) begin
                  queue_row[queue_tail] <= ni;
                  queue_col[queue_tail] <= nj;
                  queue_tail <= queue_tail + 1;
                  
                  if (queue_tail == 64) begin
                    queue_full <= 1;
                  end
                  
                  if (queue_tail == queue_head) begin
                    queue_empty <= 0;
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  // Done signal
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
    end else if (current_state == DONE) begin
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule