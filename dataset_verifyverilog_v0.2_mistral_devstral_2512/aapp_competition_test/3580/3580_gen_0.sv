module longest_valid_prefix (
  input clk,
  input rst_n,
  input start,
  input [3:0] start_index,
  input [7:0] b_data [0:7],
  input [3:0] b_size,
  output reg [3:0] result,
  output reg done
);

  // Hard-coded sequence 'a' for simulation
  localparam [7:0] a [0:15] = '{1, 2, 3, 1, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0};

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COMPUTE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [3:0] current_index;
  reg [3:0] length;
  reg [7:0] current_value;
  reg [7:0] b_element;
  reg found;
  reg [2:0] b_check_index;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = COMPUTE;
      end
      COMPUTE: begin
        if (current_index == 15 || !found || length == 15) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (start) next_state = COMPUTE;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
      current_index <= 0;
      length <= 0;
      current_value <= 0;
      b_check_index <= 0;
      found <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          result <= 0;
          done <= 0;
          current_index <= start_index;
          length <= 0;
          current_value <= a[start_index];
          b_check_index <= 0;
          found <= 0;
        end
        COMPUTE: begin
          // Check if current value is in B
          if (b_check_index == 0) begin
            found <= 0;
            b_element <= b_data[0];
          end
          if (b_element == current_value && b_check_index < b_size) begin
            found <= 1;
          end
          if (b_check_index == b_size - 1) begin
            if (found) begin
              length <= length + 1;
              if (current_index < 15) begin
                current_index <= current_index + 1;
                current_value <= a[current_index + 1];
              end
            end
            b_check_index <= 0;
          end else begin
            b_check_index <= b_check_index + 1;
            b_element <= b_data[b_check_index + 1];
          end
        end
        DONE: begin
          result <= length + 1;
          done <= 1;
        end
      endcase
    end
  end

endmodule