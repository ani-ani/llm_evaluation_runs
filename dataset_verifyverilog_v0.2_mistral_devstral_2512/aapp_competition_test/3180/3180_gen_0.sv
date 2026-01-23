module drawing_canvas (
  input clk,
  input rst_n,
  input start,
  input [5:0] cmd_type,
  input [3:0] color,
  input [1:0] x1, y1,
  input [1:0] x2, y2,
  input [1:0] load_idx,
  output reg [3:0] pixel_data,
  output reg [3:0] pixel_addr_x,
  output reg [3:0] pixel_addr_y,
  output reg pixel_wr,
  output reg done
);

  // Internal state definitions
  typedef enum logic [2:0] {
    IDLE,
    FETCH_CMD,
    PAINT_LOOP,
    SAVE_OP,
    LOAD_OP,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers for 4x4 grid
  reg [3:0] grid [0:3][0:3];

  // Save buffers (2 slots)
  reg [3:0] save_buffer_1 [0:3][0:3];
  reg [3:0] save_buffer_2 [0:3][0:3];

  // Command counter (up to 8 commands)
  reg [2:0] cmd_counter;

  // Loop counters for PAINT
  reg [1:0] x_counter, y_counter;

  // Save/Load index
  reg [1:0] save_idx;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      cmd_counter <= 0;
      x_counter <= 0;
      y_counter <= 0;
      save_idx <= 0;
      pixel_wr <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = FETCH_CMD;
      end
      FETCH_CMD: begin
        next_state = DONE; // Default to DONE if no more commands
        if (cmd_counter < 8) begin
          case (cmd_type)
            0: next_state = PAINT_LOOP; // PAINT
            1: next_state = SAVE_OP;   // SAVE
            2: next_state = LOAD_OP;   // LOAD
          endcase
        end
      end
      PAINT_LOOP: begin
        if (x_counter == x2 && y_counter == y2) begin
          next_state = FETCH_CMD;
          cmd_counter = cmd_counter + 1;
        end
      end
      SAVE_OP: begin
        next_state = FETCH_CMD;
        cmd_counter = cmd_counter + 1;
      end
      LOAD_OP: begin
        next_state = FETCH_CMD;
        cmd_counter = cmd_counter + 1;
      end
      DONE: begin
        if (cmd_counter >= 8) next_state = DONE;
      end
    endcase
  end

  // Command processing
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all internal registers
      for (int i = 0; i < 4; i++) begin
        for (int j = 0; j < 4; j++) begin
          grid[i][j] <= 0;
          save_buffer_1[i][j] <= 0;
          save_buffer_2[i][j] <= 0;
        end
      end
    end else begin
      case (current_state)
        FETCH_CMD: begin
          // Initialize loop counters for PAINT
          if (cmd_type == 0) begin
            x_counter <= x1;
            y_counter <= y1;
          end
          // Store save index for SAVE/LOAD
          if (cmd_type == 1 || cmd_type == 2) begin
            save_idx <= load_idx;
          end
        end
        PAINT_LOOP: begin
          // Check if (x + y) is even
          if ((x_counter + y_counter) % 2 == 0) begin
            grid[x_counter][y_counter] <= color;
            pixel_data <= color;
            pixel_addr_x <= x_counter;
            pixel_addr_y <= y_counter;
            pixel_wr <= 1;
          end else begin
            pixel_wr <= 0;
          end
          // Increment counters
          if (y_counter == y2) begin
            if (x_counter < x2) begin
              x_counter <= x_counter + 1;
              y_counter <= y1;
            end
          end else begin
            y_counter <= y_counter + 1;
          end
        end
        SAVE_OP: begin
          // Copy grid to save buffer
          if (save_idx == 1) begin
            for (int i = 0; i < 4; i++) begin
              for (int j = 0; j < 4; j++) begin
                save_buffer_1[i][j] <= grid[i][j];
              end
            end
          end else if (save_idx == 2) begin
            for (int i = 0; i < 4; i++) begin
              for (int j = 0; j < 4; j++) begin
                save_buffer_2[i][j] <= grid[i][j];
              end
            end
          end
        end
        LOAD_OP: begin
          // Copy save buffer to grid
          if (save_idx == 1) begin
            for (int i = 0; i < 4; i++) begin
              for (int j = 0; j < 4; j++) begin
                grid[i][j] <= save_buffer_1[i][j];
              end
            end
          end else if (save_idx == 2) begin
            for (int i = 0; i < 4; i++) begin
              for (int j = 0; j < 4; j++) begin
                grid[i][j] <= save_buffer_2[i][j];
              end
            end
          end
        end
        DONE: begin
          if (cmd_counter >= 8) done <= 1;
        end
      endcase
    end
  end

  // Default outputs
  always @(*) begin
    if (current_state != PAINT_LOOP || (x_counter + y_counter) % 2 != 0) begin
      pixel_wr = 0;
    end
  end

endmodule