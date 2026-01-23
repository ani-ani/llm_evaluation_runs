module flatten_unique (
  input clk,
  input rst_n,
  input start,
  input [2:0][7:0] tuple_0,
  input [2:0][7:0] tuple_1,
  input [2:0][7:0] tuple_2,
  output reg [7:0] result_data,
  output reg [2:0] result_count,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    CHECK_TUPLE0,
    CHECK_TUPLE1,
    CHECK_TUPLE2,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal buffer for unique values (max 9 elements)
  reg [7:0] buffer [0:8];
  reg [3:0] buffer_ptr = 0;

  // Tuple processing counters
  reg [1:0] tuple_idx = 0;  // Current tuple being processed (0-2)
  reg [1:0] elem_idx = 0;   // Current element within tuple (0-2)

  // Current element being processed
  reg [7:0] current_elem;

  // Check if element exists in buffer
  reg elem_exists;
  reg [3:0] check_idx = 0;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      buffer_ptr <= 0;
      tuple_idx <= 0;
      elem_idx <= 0;
      result_count <= 0;
      done <= 0;
      result_data <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = CHECK_TUPLE0;
      end
      CHECK_TUPLE0: begin
        if (elem_exists) begin
          if (elem_idx == 2) begin
            if (tuple_idx == 0) next_state = CHECK_TUPLE1;
            else if (tuple_idx == 1) next_state = CHECK_TUPLE2;
            else next_state = DONE;
          end
        end else begin
          if (check_idx == buffer_ptr) begin
            if (elem_idx == 2) begin
              if (tuple_idx == 0) next_state = CHECK_TUPLE1;
              else if (tuple_idx == 1) next_state = CHECK_TUPLE2;
              else next_state = DONE;
            end
          end
        end
      end
      CHECK_TUPLE1: begin
        if (elem_exists) begin
          if (elem_idx == 2) begin
            if (tuple_idx == 1) next_state = CHECK_TUPLE2;
            else next_state = DONE;
          end
        end else begin
          if (check_idx == buffer_ptr) begin
            if (elem_idx == 2) begin
              if (tuple_idx == 1) next_state = CHECK_TUPLE2;
              else next_state = DONE;
            end
          end
        end
      end
      CHECK_TUPLE2: begin
        if (elem_exists) begin
          if (elem_idx == 2) next_state = DONE;
        end else begin
          if (check_idx == buffer_ptr) begin
            if (elem_idx == 2) next_state = DONE;
          end
        end
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Element selection logic
  always @(*) begin
    case (current_state)
      CHECK_TUPLE0: begin
        case (tuple_idx)
          0: current_elem = tuple_0[elem_idx];
          1: current_elem = tuple_1[elem_idx];
          2: current_elem = tuple_2[elem_idx];
        endcase
      end
      CHECK_TUPLE1: begin
        case (tuple_idx)
          0: current_elem = tuple_0[elem_idx];
          1: current_elem = tuple_1[elem_idx];
          2: current_elem = tuple_2[elem_idx];
        endcase
      end
      CHECK_TUPLE2: begin
        case (tuple_idx)
          0: current_elem = tuple_0[elem_idx];
          1: current_elem = tuple_1[elem_idx];
          2: current_elem = tuple_2[elem_idx];
        endcase
      end
      default: current_elem = 0;
    endcase
  end

  // Uniqueness check logic
  always @(*) begin
    elem_exists = 0;
    for (int i = 0; i < buffer_ptr; i++) begin
      if (buffer[i] == current_elem) begin
        elem_exists = 1;
        break;
      end
    end
  end

  // Buffer update and output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      buffer_ptr <= 0;
      tuple_idx <= 0;
      elem_idx <= 0;
      check_idx <= 0;
      result_count <= 0;
      done <= 0;
      result_data <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          if (start) begin
            tuple_idx <= 0;
            elem_idx <= 0;
            check_idx <= 0;
            result_count <= 0;
            done <= 0;
          end
        end
        CHECK_TUPLE0, CHECK_TUPLE1, CHECK_TUPLE2: begin
          if (!elem_exists && check_idx == buffer_ptr) begin
            buffer[buffer_ptr] <= current_elem;
            buffer_ptr <= buffer_ptr + 1;
            result_data <= current_elem;
            result_count <= result_count + 1;
          end
          if (elem_exists || check_idx == buffer_ptr) begin
            if (elem_idx == 2) begin
              elem_idx <= 0;
              if (tuple_idx == 2) begin
                tuple_idx <= 0;
              end else begin
                tuple_idx <= tuple_idx + 1;
              end
            end else begin
              elem_idx <= elem_idx + 1;
            end
            check_idx <= 0;
          end else begin
            check_idx <= check_idx + 1;
          end
        end
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end

endmodule