module histogram_max (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in [0:15],
  output reg [3:0] max_count,
  output reg [25:0] max_letters,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COUNTING,
    FINDING_MAX,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Counters for each letter (a-z)
  reg [3:0] counts [0:25];

  // Internal registers
  reg [3:0] current_max;
  reg [25:0] current_mask;
  reg [3:0] cycle_count;
  reg [3:0] letter_index;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      max_count <= 4'b0;
      max_letters <= 26'b0;
      cycle_count <= 4'b0;
      letter_index <= 4'b0;
      current_max <= 4'b0;
      current_mask <= 26'b0;
      for (int i = 0; i < 26; i++) begin
        counts[i] <= 4'b0;
      end
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
          next_state = COUNTING;
          cycle_count = 4'b0;
          letter_index = 4'b0;
          current_max = 4'b0;
          current_mask = 26'b0;
          for (int i = 0; i < 26; i++) begin
            counts[i] = 4'b0;
          end
        end
      end
      COUNTING: begin
        if (cycle_count == 4'd15) begin
          next_state = FINDING_MAX;
          letter_index = 4'b0;
        end else begin
          cycle_count = cycle_count + 1'b1;
        end
      end
      FINDING_MAX: begin
        if (letter_index == 4'd25) begin
          next_state = DONE;
          max_count = current_max;
          max_letters = current_mask;
          done = 1'b1;
        end else begin
          letter_index = letter_index + 1'b1;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
          done = 1'b0;
        end
      end
    endcase
  end

  // Counting logic
  always @(posedge clk) begin
    if (current_state == COUNTING) begin
      if (char_in[cycle_count] != 8'h20) begin
        if (char_in[cycle_count] >= 8'h61 && char_in[cycle_count] <= 8'h7a) begin
          counts[char_in[cycle_count] - 8'h61] <= counts[char_in[cycle_count] - 8'h61] + 1'b1;
        end
      end
    end
  end

  // Max finding logic
  always @(posedge clk) begin
    if (current_state == FINDING_MAX) begin
      if (counts[letter_index] > current_max) begin
        current_max <= counts[letter_index];
        current_mask <= 1'b1 << letter_index;
      end else if (counts[letter_index] == current_max) begin
        current_mask <= current_mask | (1'b1 << letter_index);
      end
    end
  end

endmodule