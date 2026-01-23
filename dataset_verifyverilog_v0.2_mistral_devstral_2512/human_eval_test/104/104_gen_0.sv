module unique_digits (
  input clk,
  input rst_n,
  input start,
  input [13:0] in0, in1, in2, in3,
  output reg [13:0] out0, out1, out2, out3,
  output reg [2:0] count,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    PARSE_0,
    PARSE_1,
    PARSE_2,
    PARSE_3,
    FILTER,
    SORT,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [13:0] num0, num1, num2, num3;
  reg valid0, valid1, valid2, valid3;
  reg [13:0] buffer [0:3];
  reg [1:0] buffer_idx;
  reg [1:0] sort_i, sort_j;
  reg [13:0] temp;

  // Digit extraction variables
  reg [13:0] current_num;
  reg [3:0] digit;
  reg [1:0] digit_idx;
  reg all_odd;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      count <= 0;
      out0 <= 0;
      out1 <= 0;
      out2 <= 0;
      out3 <= 0;
      num0 <= 0;
      num1 <= 0;
      num2 <= 0;
      num3 <= 0;
      valid0 <= 0;
      valid1 <= 0;
      valid2 <= 0;
      valid3 <= 0;
      buffer_idx <= 0;
      sort_i <= 0;
      sort_j <= 0;
      digit_idx <= 0;
      all_odd <= 1;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = PARSE_0;
      end
      PARSE_0: begin
        if (digit_idx == 4) next_state = PARSE_1;
      end
      PARSE_1: begin
        if (digit_idx == 4) next_state = PARSE_2;
      end
      PARSE_2: begin
        if (digit_idx == 4) next_state = PARSE_3;
      end
      PARSE_3: begin
        if (digit_idx == 4) next_state = FILTER;
      end
      FILTER: begin
        if (buffer_idx == 4) next_state = SORT;
      end
      SORT: begin
        if (sort_i == 4) next_state = DONE;
      end
      DONE: begin
        if (start) next_state = PARSE_0;
      end
      default: next_state = IDLE;
    endcase
  end

  // Digit extraction and validation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      digit_idx <= 0;
      all_odd <= 1;
    end else begin
      case (state)
        PARSE_0: begin
          if (digit_idx == 0) begin
            current_num <= in0;
            all_odd <= 1;
          end
          if (digit_idx < 4) begin
            digit <= current_num % 10;
            if (digit[0] == 0) all_odd <= 0;
            current_num <= current_num / 10;
            digit_idx <= digit_idx + 1;
          end
          if (digit_idx == 4) begin
            valid0 <= all_odd;
            digit_idx <= 0;
          end
        end
        PARSE_1: begin
          if (digit_idx == 0) begin
            current_num <= in1;
            all_odd <= 1;
          end
          if (digit_idx < 4) begin
            digit <= current_num % 10;
            if (digit[0] == 0) all_odd <= 0;
            current_num <= current_num / 10;
            digit_idx <= digit_idx + 1;
          end
          if (digit_idx == 4) begin
            valid1 <= all_odd;
            digit_idx <= 0;
          end
        end
        PARSE_2: begin
          if (digit_idx == 0) begin
            current_num <= in2;
            all_odd <= 1;
          end
          if (digit_idx < 4) begin
            digit <= current_num % 10;
            if (digit[0] == 0) all_odd <= 0;
            current_num <= current_num / 10;
            digit_idx <= digit_idx + 1;
          end
          if (digit_idx == 4) begin
            valid2 <= all_odd;
            digit_idx <= 0;
          end
        end
        PARSE_3: begin
          if (digit_idx == 0) begin
            current_num <= in3;
            all_odd <= 1;
          end
          if (digit_idx < 4) begin
            digit <= current_num % 10;
            if (digit[0] == 0) all_odd <= 0;
            current_num <= current_num / 10;
            digit_idx <= digit_idx + 1;
          end
          if (digit_idx == 4) begin
            valid3 <= all_odd;
            digit_idx <= 0;
          end
        end
      endcase
    end
  end

  // Filter valid numbers into buffer
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      buffer_idx <= 0;
    end else if (state == FILTER) begin
      if (buffer_idx < 4) begin
        case (buffer_idx)
          0: buffer[0] <= valid0 ? in0 : 0;
          1: buffer[1] <= valid1 ? in1 : 0;
          2: buffer[2] <= valid2 ? in2 : 0;
          3: buffer[3] <= valid3 ? in3 : 0;
        endcase
        buffer_idx <= buffer_idx + 1;
      end
    end
  end

  // Insertion sort
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sort_i <= 0;
      sort_j <= 0;
    end else if (state == SORT) begin
      if (sort_i < 4) begin
        if (sort_j > 0 && buffer[sort_j-1] > temp) begin
          buffer[sort_j] <= buffer[sort_j-1];
          sort_j <= sort_j - 1;
        end else begin
          buffer[sort_j] <= temp;
          sort_i <= sort_i + 1;
          sort_j <= sort_i;
          temp <= buffer[sort_i];
        end
      end
    end
  end

  // Output results
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      count <= 0;
      out0 <= 0;
      out1 <= 0;
      out2 <= 0;
      out3 <= 0;
    end else if (state == DONE) begin
      done <= 1;
      count <= (valid0 ? 1 : 0) + (valid1 ? 1 : 0) + (valid2 ? 1 : 0) + (valid3 ? 1 : 0);
      out0 <= buffer[0];
      out1 <= buffer[1];
      out2 <= buffer[2];
      out3 <= buffer[3];
    end else begin
      done <= 0;
    end
  end

endmodule