module rearrange_bigger(
  input clk,
  input rst_n,
  input start,
  input [11:0] number_in,
  output reg [11:0] result,
  output reg done,
  output reg valid
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    EXTRACT_DIGITS,
    FIND_PIVOT,
    FIND_MIN_GREATER,
    SWAP_DIGITS,
    SORT_REMAINING,
    COMPOSE_RESULT,
    DONE
  } state_t;

  state_t state, next_state;

  // Digit registers (8-bit for simplicity)
  reg [7:0] d [0:2]; // d[2]=hundreds, d[1]=tens, d[0]=units

  // Intermediate registers
  reg [1:0] pivot_pos; // Position of pivot digit
  reg [1:0] swap_pos;  // Position of digit to swap with pivot
  reg [7:0] min_val;   // Minimum value found in FIND_MIN_GREATER
  reg [1:0] min_pos;   // Position of minimum value
  reg [7:0] temp;      // Temporary storage for sorting
  reg [11:0] counter;  // Cycle counter for sorting

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      valid <= 0;
      result <= 0;
      counter <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = EXTRACT_DIGITS;
      end
      EXTRACT_DIGITS: next_state = FIND_PIVOT;
      FIND_PIVOT: next_state = FIND_MIN_GREATER;
      FIND_MIN_GREATER: next_state = SWAP_DIGITS;
      SWAP_DIGITS: next_state = SORT_REMAINING;
      SORT_REMAINING: begin
        if (counter == 2) next_state = COMPOSE_RESULT;
      end
      COMPOSE_RESULT: next_state = DONE;
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Digit extraction
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      d[0] <= 0; d[1] <= 0; d[2] <= 0;
    end else if (state == EXTRACT_DIGITS) begin
      d[0] <= number_in % 10;      // Units
      d[1] <= (number_in / 10) % 10; // Tens
      d[2] <= number_in / 100;     // Hundreds
    end
  end

  // Find pivot position
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pivot_pos <= 0;
    end else if (state == FIND_PIVOT) begin
      // Check d[1] < d[2] first
      if (d[1] < d[2]) pivot_pos <= 1;
      // Then check d[0] < d[1]
      else if (d[0] < d[1]) pivot_pos <= 0;
      else pivot_pos <= 3; // No pivot found
    end
  end

  // Find minimum greater digit
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      min_val <= 0;
      min_pos <= 0;
    end else if (state == FIND_MIN_GREATER) begin
      if (pivot_pos == 3) begin
        min_val <= 0; min_pos <= 0;
      end else begin
        // Compare d[pivot_pos+1] and d[pivot_pos+2]
        if (d[pivot_pos+1] > d[pivot_pos] && 
            (d[pivot_pos+2] <= d[pivot_pos] || 
             d[pivot_pos+1] < d[pivot_pos+2])) begin
          min_val <= d[pivot_pos+1];
          min_pos <= pivot_pos+1;
        end else if (d[pivot_pos+2] > d[pivot_pos]) begin
          min_val <= d[pivot_pos+2];
          min_pos <= pivot_pos+2;
        end else begin
          min_val <= 0; min_pos <= 0;
        end
      end
    end
  end

  // Swap digits
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      swap_pos <= 0;
    end else if (state == SWAP_DIGITS) begin
      if (pivot_pos != 3 && min_pos != 0) begin
        swap_pos <= min_pos;
        // Perform swap
        temp <= d[pivot_pos];
        d[pivot_pos] <= d[swap_pos];
        d[swap_pos] <= temp;
      end
    end
  end

  // Sort remaining digits
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter <= 0;
    end else if (state == SORT_REMAINING) begin
      if (counter < 2) begin
        // Bubble sort pass
        if (d[pivot_pos+1] > d[pivot_pos+2]) begin
          temp <= d[pivot_pos+1];
          d[pivot_pos+1] <= d[pivot_pos+2];
          d[pivot_pos+2] <= temp;
        end
        counter <= counter + 1;
      end
    end else begin
      counter <= 0;
    end
  end

  // Compose result
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      valid <= 0;
      done <= 0;
    end else if (state == COMPOSE_RESULT) begin
      if (pivot_pos == 3) begin
        result <= 12'hFFF;
        valid <= 0;
      end else begin
        result <= d[2] * 100 + d[1] * 10 + d[0];
        valid <= 1;
      end
    end else if (state == DONE) begin
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule