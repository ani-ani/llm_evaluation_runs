module perfect_squares (
  input clk,
  input rst_n,
  input start,
  input [7:0] a,
  input [7:0] b,
  output reg [7:0] result,
  output reg [3:0] count,
  output reg done,
  output reg valid
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CHECK_NUMBER,
    FIND_SQUARE,
    STORE_RESULT,
    OUTPUT_RESULTS,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [7:0] current_num;
  reg [3:0] j;
  reg [7:0] result_array [0:7];
  reg [2:0] result_idx;
  reg [2:0] output_idx;
  reg [3:0] square_count;
  reg found;

  // Default assignments
  assign result = 8'h0;
  assign count = 4'h0;
  assign done = 1'b0;
  assign valid = 1'b0;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_num <= 8'h0;
      j <= 4'h0;
      result_idx <= 3'h0;
      output_idx <= 3'h0;
      square_count <= 4'h0;
      found <= 1'b0;
      done <= 1'b0;
      valid <= 1'b0;
      count <= 4'h0;
      result <= 8'h0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CHECK_NUMBER;
      end
      CHECK_NUMBER: begin
        if (current_num > b) next_state = OUTPUT_RESULTS;
        else next_state = FIND_SQUARE;
      end
      FIND_SQUARE: begin
        if (j == 15) next_state = CHECK_NUMBER;
        else if (found) next_state = STORE_RESULT;
      end
      STORE_RESULT: begin
        next_state = CHECK_NUMBER;
      end
      OUTPUT_RESULTS: begin
        if (output_idx == square_count) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_num <= 8'h0;
      j <= 4'h0;
      result_idx <= 3'h0;
      output_idx <= 3'h0;
      square_count <= 4'h0;
      found <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            current_num <= a;
            j <= 4'h1;
            result_idx <= 3'h0;
            output_idx <= 3'h0;
            square_count <= 4'h0;
            found <= 1'b0;
            done <= 1'b0;
            count <= 4'h0;
          end
        end
        CHECK_NUMBER: begin
          if (current_num > b) begin
            // No action needed, handled in next state
          end else begin
            j <= 4'h1;
            found <= 1'b0;
          end
        end
        FIND_SQUARE: begin
          if (j == 15) begin
            current_num <= current_num + 1'b1;
            j <= 4'h1;
          end else if (found) begin
            // Handled in STORE_RESULT
          end else begin
            j <= j + 1'b1;
          end
        end
        STORE_RESULT: begin
          result_array[result_idx] <= current_num;
          result_idx <= result_idx + 1'b1;
          square_count <= square_count + 1'b1;
          current_num <= current_num + 1'b1;
          j <= 4'h1;
          found <= 1'b0;
        end
        OUTPUT_RESULTS: begin
          if (output_idx == square_count) begin
            // No action needed
          end else begin
            result <= result_array[output_idx];
            count <= square_count;
            valid <= 1'b1;
            output_idx <= output_idx + 1'b1;
          end
        end
        DONE: begin
          done <= 1'b1;
          valid <= 1'b0;
        end
        default: begin
          // Default case
        end
      endcase
    end
  end

  // Combinational logic for found detection
  always @(*) begin
    if (state == FIND_SQUARE && j <= 15) begin
      if (j * j == current_num) begin
        found = 1'b1;
      end else begin
        found = 1'b0;
      end
    end else begin
      found = 1'b0;
    end
  end

endmodule