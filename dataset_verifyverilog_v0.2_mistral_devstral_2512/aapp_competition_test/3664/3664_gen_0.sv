module pacman_ice_cleaning (
  input clk,
  input rst_n,
  input start,
  input [3:0] r,
  input [3:0] c,
  input [3:0] start_i,
  input [3:0] start_j,
  input [5:0] n,
  output reg [7:0] ram_write_addr,
  output reg [7:0] ram_write_data,
  output reg ram_write_en,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    EXEC_LOOP,
    MOVE_STEPS,
    WAIT_STATE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [3:0] rows, cols;
  reg [3:0] pos_i, pos_j;
  reg [5:0] numSteps, stepSize;
  reg [5:0] outer_loop_cnt, inner_loop_cnt;
  reg [7:0] current_color;
  reg [1:0] current_dir;
  reg [7:0] addr;

  // Direction encoding: 0=Up, 1=Right, 2=Down, 3=Left
  parameter UP = 2'b00, RIGHT = 2'b01, DOWN = 2'b10, LEFT = 2'b11;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      ram_write_en <= 1'b0;
      ram_write_addr <= 8'b0;
      ram_write_data <= 8'b0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = EXEC_LOOP;
      end
      EXEC_LOOP: begin
        if (outer_loop_cnt == 0) next_state = WAIT_STATE;
        else next_state = MOVE_STEPS;
      end
      MOVE_STEPS: begin
        if (inner_loop_cnt == 0) next_state = EXEC_LOOP;
        else next_state = MOVE_STEPS;
      end
      WAIT_STATE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rows <= 4'b0;
      cols <= 4'b0;
      pos_i <= 4'b0;
      pos_j <= 4'b0;
      numSteps <= 6'b0;
      stepSize <= 6'b0;
      outer_loop_cnt <= 6'b0;
      inner_loop_cnt <= 6'b0;
      current_color <= 8'b0;
      current_dir <= 2'b0;
      addr <= 8'b0;
    end else begin
      case (current_state)
        IDLE: begin
          if (start) begin
            rows <= r;
            cols <= c;
            pos_i <= start_i - 1;
            pos_j <= start_j - 1;
            numSteps <= n;
            stepSize <= 1;
            outer_loop_cnt <= numSteps;
            inner_loop_cnt <= stepSize;
            current_color <= "A";
            current_dir <= UP;
            addr <= {pos_i, pos_j};
          end
        end
        EXEC_LOOP: begin
          if (outer_loop_cnt == 0) begin
            // Final step: write '@'
            ram_write_en <= 1'b1;
            ram_write_addr <= addr;
            ram_write_data <= "@";
            done <= 1'b1;
          end else begin
            // Rotate direction and increment stepSize
            current_dir <= (current_dir + 1) % 4;
            stepSize <= stepSize + 1;
            inner_loop_cnt <= stepSize;
            outer_loop_cnt <= outer_loop_cnt - 1;
          end
        end
        MOVE_STEPS: begin
          if (inner_loop_cnt > 0) begin
            // Write current color
            ram_write_en <= 1'b1;
            ram_write_addr <= addr;
            ram_write_data <= current_color;

            // Update position
            case (current_dir)
              UP: pos_i <= (pos_i - 1 + rows) % rows;
              RIGHT: pos_j <= (pos_j + 1) % cols;
              DOWN: pos_i <= (pos_i + 1) % rows;
              LEFT: pos_j <= (pos_j - 1 + cols) % cols;
            endcase

            // Update color (A-Z wrap)
            if (current_color == "Z") current_color <= "A";
            else current_color <= current_color + 1;

            // Update address
            addr <= {pos_i, pos_j};

            // Decrement inner loop counter
            inner_loop_cnt <= inner_loop_cnt - 1;
          end
        end
        WAIT_STATE: begin
          ram_write_en <= 1'b0;
        end
        default: begin
          ram_write_en <= 1'b0;
        end
      endcase
    end
  end

  // Default outputs
  assign ram_write_en = (current_state == MOVE_STEPS || (current_state == EXEC_LOOP && outer_loop_cnt == 0)) ? 1'b1 : 1'b0;

endmodule