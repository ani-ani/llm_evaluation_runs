module bits_game (
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  input [3:0] K,
  input [31:0] A [0:15],
  output reg [31:0] result,
  output reg done
);

  // States
  typedef enum logic [3:0] {
    IDLE,
    CHECK_BIT,
    VERIFY_SECTIONS,
    UPDATE_RESULT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Bit checking variables
  reg [4:0] bit_pos;
  reg [31:0] current_result;
  reg [31:0] current_or;
  reg [3:0] section_count;
  reg [3:0] array_index;
  reg [3:0] section_start;
  reg bit_set;
  reg [3:0] section_counter;

  // Counters and flags
  reg [9:0] cycle_counter;
  reg bit_feasible;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 0;
      done <= 0;
      bit_pos <= 0;
      current_result <= 0;
      current_or <= 0;
      section_count <= 0;
      array_index <= 0;
      section_start <= 0;
      bit_set <= 0;
      section_counter <= 0;
      cycle_counter <= 0;
      bit_feasible <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = CHECK_BIT;
          current_result = 0;
          bit_pos = 31;
          cycle_counter = 0;
        end
      end
      CHECK_BIT: begin
        if (cycle_counter >= 500) begin
          next_state = DONE;
        end else if (bit_pos < 0) begin
          next_state = DONE;
        end else begin
          next_state = VERIFY_SECTIONS;
          current_or = 0;
          section_count = 0;
          array_index = 0;
          section_start = 0;
          bit_set = 0;
          section_counter = 0;
        end
      end
      VERIFY_SECTIONS: begin
        if (section_count >= K) begin
          bit_feasible = 1;
          next_state = UPDATE_RESULT;
        end else if (array_index == N) begin
          bit_feasible = 0;
          next_state = UPDATE_RESULT;
        end
      end
      UPDATE_RESULT: begin
        if (bit_feasible) begin
          current_result = current_result | (1 << bit_pos);
        end
        next_state = CHECK_BIT;
        bit_pos = bit_pos - 1;
        cycle_counter = cycle_counter + 1;
      end
      DONE: begin
        result = current_result;
        done = 1;
      end
      default: next_state = IDLE;
    endcase
  end

  // Verification logic
  always @(posedge clk) begin
    if (current_state == VERIFY_SECTIONS) begin
      if (array_index < N) begin
        current_or = current_or | A[array_index];
        if ((current_or & (1 << bit_pos)) && !bit_set) begin
          section_count = section_count + 1;
          bit_set = 1;
          section_start = array_index + 1;
        end
        array_index = array_index + 1;
      end else begin
        array_index = 0;
      end
    end
  end

endmodule