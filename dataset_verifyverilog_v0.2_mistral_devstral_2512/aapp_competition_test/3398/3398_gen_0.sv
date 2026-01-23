module min_moves (
  input clk,
  input rst_n,
  input start,
  input [5:0] total_files,
  input [9:0] file_coords [0:9],
  input [9:0] num_delete,
  output reg [3:0] min_moves,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    INIT_SUBSET,
    CHECK_SUBSET,
    UPDATE_RESULT,
    DONE
  } state_t;
  state_t state, next_state;

  // Internal registers
  reg [3:0] current_k; // Current subset size (0 to num_delete)
  reg [3:0] current_comb; // Current combination index
  reg [9:0] subset_mask; // Bitmask representing current subset
  reg [3:0] min_moves_reg; // Internal min_moves register
  reg done_reg; // Internal done register

  // Bounding box registers for remaining targets
  reg [9:0] min_row, max_row, min_col, max_col;
  reg [3:0] target_count; // Number of remaining targets

  // Combinatorial logic for state transitions
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT_SUBSET;
      end
      INIT_SUBSET: begin
        if (current_k == num_delete) next_state = DONE;
        else next_state = CHECK_SUBSET;
      end
      CHECK_SUBSET: begin
        if (current_comb == (1 << num_delete) - 1) next_state = UPDATE_RESULT;
        else next_state = CHECK_SUBSET;
      end
      UPDATE_RESULT: begin
        next_state = INIT_SUBSET;
      end
      DONE: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic for state machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_k <= 0;
      current_comb <= 0;
      subset_mask <= 0;
      min_moves_reg <= 0;
      done_reg <= 0;
      min_row <= 0;
      max_row <= 0;
      min_col <= 0;
      max_col <= 0;
      target_count <= 0;
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          done_reg <= 0;
          min_moves_reg <= 0;
        end
        INIT_SUBSET: begin
          current_k <= current_k + 1;
          current_comb <= 0;
          subset_mask <= 0;
        end
        CHECK_SUBSET: begin
          current_comb <= current_comb + 1;
          subset_mask <= current_comb;
        end
        UPDATE_RESULT: begin
          if (min_moves_reg == 0) begin
            min_moves_reg <= current_k;
          end
        end
        DONE: begin
          done_reg <= 1;
        end
      endcase
    end
  end

  // Compute bounding box of remaining targets
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      min_row <= 0;
      max_row <= 0;
      min_col <= 0;
      max_col <= 0;
      target_count <= 0;
    end else if (state == CHECK_SUBSET) begin
      reg [9:0] temp_min_row = 10'h3FF;
      reg [9:0] temp_max_row = 10'h000;
      reg [9:0] temp_min_col = 10'h3FF;
      reg [9:0] temp_max_col = 10'h000;
      reg [3:0] temp_count = 0;

      for (int i = 0; i < num_delete; i++) begin
        if (!(subset_mask[i])) begin
          reg [9:0] row = file_coords[i][19:10];
          reg [9:0] col = file_coords[i][9:0];
          if (row < temp_min_row) temp_min_row = row;
          if (row > temp_max_row) temp_max_row = row;
          if (col < temp_min_col) temp_min_col = col;
          if (col > temp_max_col) temp_max_col = col;
          temp_count = temp_count + 1;
        end
      end

      min_row <= temp_min_row;
      max_row <= temp_max_row;
      min_col <= temp_min_col;
      max_col <= temp_max_col;
      target_count <= temp_count;
    end
  end

  // Check if any kept file is inside the bounding box
  reg valid_subset;
  always_comb begin
    valid_subset = 1;
    if (target_count == 0) begin
      valid_subset = 1;
    end else begin
      for (int i = num_delete; i < total_files; i++) begin
        reg [9:0] row = file_coords[i][19:10];
        reg [9:0] col = file_coords[i][9:0];
        if (row >= min_row && row <= max_row && col >= min_col && col <= max_col) begin
          valid_subset = 0;
        end
      end
    end
  end

  // Update min_moves if valid subset found
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      min_moves_reg <= 0;
    end else if (state == CHECK_SUBSET && valid_subset && min_moves_reg == 0) begin
      min_moves_reg <= current_k;
    end
  end

  // Output assignments
  assign min_moves = min_moves_reg;
  assign done = done_reg;

endmodule