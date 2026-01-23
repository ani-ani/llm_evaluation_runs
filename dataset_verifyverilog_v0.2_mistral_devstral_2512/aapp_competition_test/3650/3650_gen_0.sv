module sliding_blocks_solver (
  input clk,
  input rst_n,
  input start,
  input [63:0] target_matrix,
  input [5:0] initial_r,
  input [5:0] initial_c,
  output reg [7:0] move_count,
  output reg [31:0] move_data,
  output reg move_valid,
  output reg solve_done,
  output reg possible
);

  // State machine states
  typedef enum logic [3:0] {
    IDLE,
    CHECK_NEIGHBORS,
    OUTPUT_MOVE,
    VERIFY_COMPLETE,
    DONE
  } state_t;
  state_t state, next_state;

  // Internal registers
  reg [5:0] current_r, current_c;
  reg [63:0] visited_matrix;
  reg [5:0] fifo_r [0:63], fifo_c [0:63];
  reg [5:0] fifo_head, fifo_tail;
  reg [7:0] total_blocks;
  reg [7:0] processed_blocks;
  reg [31:0] move_fifo [0:63];
  reg [5:0] move_fifo_head, move_fifo_tail;

  // Direction encoding
  typedef enum logic [1:0] {
    LEFT,
    RIGHT,
    UP,
    DOWN
  } direction_t;

  // Initialize registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_r <= 0;
      current_c <= 0;
      visited_matrix <= 64'b0;
      fifo_head <= 0;
      fifo_tail <= 0;
      total_blocks <= 0;
      processed_blocks <= 0;
      move_fifo_head <= 0;
      move_fifo_tail <= 0;
      move_count <= 0;
      move_data <= 0;
      move_valid <= 0;
      solve_done <= 0;
      possible <= 0;
    end else begin
      state <= next_state;
      if (state == OUTPUT_MOVE) begin
        move_count <= move_count + 1;
      end
    end
  end

  // State machine logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = CHECK_NEIGHBORS;
          // Initialize visited matrix with initial block
          visited_matrix = 64'b0;
          visited_matrix[(initial_r - 1) * 8 + (initial_c - 1)] = 1'b1;
          fifo_head = 0;
          fifo_tail = 0;
          fifo_r[0] = initial_r - 1;
          fifo_c[0] = initial_c - 1;
          fifo_tail = 1;
          total_blocks = $countones(target_matrix);
          processed_blocks = 1;
          move_fifo_head = 0;
          move_fifo_tail = 0;
          move_count = 0;
          move_valid = 0;
          solve_done = 0;
          possible = 0;
        end
      end
      CHECK_NEIGHBORS: begin
        if (fifo_head < fifo_tail) begin
          current_r = fifo_r[fifo_head];
          current_c = fifo_c[fifo_head];
          fifo_head = fifo_head + 1;
          next_state = CHECK_NEIGHBORS;
        end else begin
          next_state = VERIFY_COMPLETE;
        end
      end
      OUTPUT_MOVE: begin
        if (move_fifo_head < move_fifo_tail) begin
          move_data = move_fifo[move_fifo_head];
          move_valid = 1;
          move_fifo_head = move_fifo_head + 1;
          next_state = OUTPUT_MOVE;
        end else begin
          move_valid = 0;
          next_state = CHECK_NEIGHBORS;
        end
      end
      VERIFY_COMPLETE: begin
        if (processed_blocks == total_blocks) begin
          possible = 1;
          next_state = DONE;
        end else begin
          possible = 0;
          next_state = DONE;
        end
      end
      DONE: begin
        solve_done = 1;
      end
      default: next_state = IDLE;
    endcase
  end

  // Neighbor checking logic
  always @(posedge clk) begin
    if (state == CHECK_NEIGHBORS) begin
      // Check all four directions
      for (int i = 0; i < 4; i++) begin
        direction_t dir = direction_t'(i);
        reg [5:0] new_r = current_r;
        reg [5:0] new_c = current_c;
        reg [5:0] check_r = current_r;
        reg [5:0] check_c = current_c;
        reg valid = 1'b0;

        case (dir)
          LEFT: begin
            new_c = current_c - 1;
            check_c = current_c + 1;
            if (new_c >= 0 && new_c < 8 && check_c < 8) begin
              if (target_matrix[new_r * 8 + new_c] && !visited_matrix[new_r * 8 + new_c]) begin
                if (!target_matrix[check_r * 8 + check_c]) begin
                  valid = 1'b1;
                end
              end
            end
          end
          RIGHT: begin
            new_c = current_c + 1;
            check_c = current_c - 1;
            if (new_c >= 0 && new_c < 8 && check_c >= 0) begin
              if (target_matrix[new_r * 8 + new_c] && !visited_matrix[new_r * 8 + new_c]) begin
                if (!target_matrix[check_r * 8 + check_c]) begin
                  valid = 1'b1;
                end
              end
            end
          end
          UP: begin
            new_r = current_r - 1;
            check_r = current_r + 1;
            if (new_r >= 0 && new_r < 8 && check_r < 8) begin
              if (target_matrix[new_r * 8 + new_c] && !visited_matrix[new_r * 8 + new_c]) begin
                if (!target_matrix[check_r * 8 + check_c]) begin
                  valid = 1'b1;
                end
              end
            end
          end
          DOWN: begin
            new_r = current_r + 1;
            check_r = current_r - 1;
            if (new_r >= 0 && new_r < 8 && check_r >= 0) begin
              if (target_matrix[new_r * 8 + new_c] && !visited_matrix[new_r * 8 + new_c]) begin
                if (!target_matrix[check_r * 8 + check_c]) begin
                  valid = 1'b1;
                end
              end
            end
          end
        endcase

        if (valid) begin
          // Add to FIFO
          fifo_r[fifo_tail] = new_r;
          fifo_c[fifo_tail] = new_c;
          fifo_tail = fifo_tail + 1;
          // Mark as visited
          visited_matrix[new_r * 8 + new_c] = 1'b1;
          // Schedule move output
          move_fifo[move_fifo_tail] = {dir, new_r, new_c};
          move_fifo_tail = move_fifo_tail + 1;
          processed_blocks = processed_blocks + 1;
        end
      end
    end
  end

endmodule