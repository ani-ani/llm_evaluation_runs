module unique (
  input clk,
  input rst_n,
  input start,
  input [7:0] data_in [0:7],
  input [2:0] valid_count,
  output reg [7:0] result [0:7],
  output reg [2:0] unique_count,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    LOAD,
    SORT,
    DEDUP,
    SHIFT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] buffer [0:7];
  reg [7:0] temp [0:7];
  reg [2:0] sort_pass;
  reg [2:0] sort_i;
  reg [2:0] dedup_i;
  reg [2:0] shift_i;
  reg [2:0] shift_j;
  reg [2:0] count;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      unique_count <= 0;
      sort_pass <= 0;
      sort_i <= 0;
      dedup_i <= 0;
      shift_i <= 0;
      shift_j <= 0;
      count <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = LOAD;
      end
      LOAD: next_state = SORT;
      SORT: begin
        if (sort_pass == 7 && sort_i == 7) next_state = DEDUP;
      end
      DEDUP: begin
        if (dedup_i == 7) next_state = SHIFT;
      end
      SHIFT: begin
        if (shift_i == 7) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Load input data
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 8; i++) buffer[i] <= 0;
    end else if (current_state == LOAD) begin
      for (int i = 0; i < 8; i++) buffer[i] <= data_in[i];
    end
  end

  // Bubble sort
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sort_pass <= 0;
      sort_i <= 0;
    end else if (current_state == SORT) begin
      if (sort_i < 7 - sort_pass) begin
        if (buffer[sort_i] > buffer[sort_i + 1]) begin
          temp[sort_i] <= buffer[sort_i];
          temp[sort_i + 1] <= buffer[sort_i + 1];
          buffer[sort_i] <= temp[sort_i + 1];
          buffer[sort_i + 1] <= temp[sort_i];
        end
        sort_i <= sort_i + 1;
      end else begin
        sort_i <= 0;
        sort_pass <= sort_pass + 1;
      end
    end
  end

  // Remove duplicates
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dedup_i <= 0;
      count <= 0;
    end else if (current_state == DEDUP) begin
      if (dedup_i < 7) begin
        if (buffer[dedup_i] == buffer[dedup_i + 1]) begin
          buffer[dedup_i + 1] <= 0;
        end else begin
          count <= count + 1;
        end
        dedup_i <= dedup_i + 1;
      end
    end
  end

  // Shift unique elements
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      shift_i <= 0;
      shift_j <= 0;
    end else if (current_state == SHIFT) begin
      if (shift_j < 8) begin
        if (buffer[shift_j] != 0) begin
          result[shift_i] <= buffer[shift_j];
          shift_i <= shift_i + 1;
        end
        shift_j <= shift_j + 1;
      end
    end
  end

  // Output done signal
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
    end else if (current_state == DONE) begin
      done <= 1;
      unique_count <= count + 1;
    end else if (current_state != DONE) begin
      done <= 0;
    end
  end

endmodule