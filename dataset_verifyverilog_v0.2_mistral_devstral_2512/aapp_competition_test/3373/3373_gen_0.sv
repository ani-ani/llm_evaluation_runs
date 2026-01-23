module balanced_parentheses_solver (
  input clk,
  input rst_n,
  input start,
  input [5:0] num_pieces,
  input [7:0][15:0] pieces,
  output reg [9:0] max_length,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    PARSE_PIECES,
    EVALUATE_SUBSETS,
    COMPUTE_BEST,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Piece metadata storage
  typedef struct {
    logic signed [4:0] min_prefix;
    logic signed [4:0] final_balance;
    logic [3:0] length;
  } piece_meta_t;

  piece_meta_t piece_meta [0:7];
  logic [2:0] piece_idx;
  logic [7:0] subset_mask;
  logic [9:0] current_max;
  logic [7:0] subset_counter;

  // Internal signals
  logic [4:0] current_balance;
  logic [9:0] current_length;
  logic [2:0] char_idx;
  logic [1:0] current_char;
  logic piece_valid;

  // State machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      max_length <= 0;
      done <= 0;
      piece_idx <= 0;
      subset_mask <= 0;
      current_max <= 0;
      subset_counter <= 0;
      current_balance <= 0;
      current_length <= 0;
      char_idx <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = PARSE_PIECES;
      end
      PARSE_PIECES: begin
        if (piece_idx == num_pieces - 1) next_state = EVALUATE_SUBSETS;
      end
      EVALUATE_SUBSETS: begin
        if (subset_counter == (1 << num_pieces) - 1) next_state = COMPUTE_BEST;
      end
      COMPUTE_BEST: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Parse pieces state
  always_ff @(posedge clk) begin
    if (current_state == PARSE_PIECES) begin
      if (char_idx == 0) begin
        piece_meta[piece_idx].min_prefix = 0;
        piece_meta[piece_idx].final_balance = 0;
        piece_meta[piece_idx].length = 0;
      end

      current_char = pieces[piece_idx][char_idx];
      piece_valid = (current_char != 2'b00 && current_char != 2'b11);

      if (piece_valid) begin
        piece_meta[piece_idx].length = piece_meta[piece_idx].length + 1;
        if (current_char == 2'b01) begin
          piece_meta[piece_idx].final_balance = piece_meta[piece_idx].final_balance + 1;
          if (piece_meta[piece_idx].min_prefix < 0)
            piece_meta[piece_idx].min_prefix = piece_meta[piece_idx].min_prefix + 1;
        end else begin // 2'b10
          piece_meta[piece_idx].final_balance = piece_meta[piece_idx].final_balance - 1;
          if (piece_meta[piece_idx].min_prefix > piece_meta[piece_idx].final_balance)
            piece_meta[piece_idx].min_prefix = piece_meta[piece_idx].final_balance;
        end
      end

      if (char_idx == 15) begin
        char_idx <= 0;
        piece_idx <= piece_idx + 1;
      end else begin
        char_idx <= char_idx + 1;
      end
    end
  end

  // Evaluate subsets state
  always_ff @(posedge clk) begin
    if (current_state == EVALUATE_SUBSETS) begin
      if (char_idx == 0) begin
        current_balance = 0;
        current_length = 0;
      end

      // Check if current piece is in subset
      if (subset_mask[piece_idx]) begin
        current_char = pieces[piece_idx][char_idx];
        piece_valid = (current_char != 2'b00 && current_char != 2'b11);

        if (piece_valid) begin
          if (current_char == 2'b01) begin
            current_balance = current_balance + 1;
          end else begin // 2'b10
            current_balance = current_balance - 1;
          end
          current_length = current_length + 1;
        end
      end

      // Check for completion
      if (char_idx == 15 && piece_idx == num_pieces - 1) begin
        if (current_balance == 0 && current_length > current_max) begin
          current_max = current_length;
        end
        char_idx <= 0;
        piece_idx <= 0;
        subset_mask <= subset_mask + 1;
        subset_counter <= subset_counter + 1;
      end else if (char_idx == 15) begin
        char_idx <= 0;
        piece_idx <= piece_idx + 1;
      end else begin
        char_idx <= char_idx + 1;
      end
    end
  end

  // Compute best state
  always_ff @(posedge clk) begin
    if (current_state == COMPUTE_BEST) begin
      max_length <= current_max;
      done <= 1;
    end else if (current_state == IDLE) begin
      done <= 0;
    end
  end

endmodule