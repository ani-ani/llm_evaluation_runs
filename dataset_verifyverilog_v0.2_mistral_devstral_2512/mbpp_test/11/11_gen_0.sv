module remove_occurrences (
  input clk,
  input rst_n,
  input start,
  input [7:0] target_char,
  input [63:0] input_str,
  output reg [63:0] result_str,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    FIND_FIRST,
    REMOVE_FIRST,
    FIND_LAST,
    REMOVE_LAST,
    DONE
  } state_t;

  state_t state, next_state;
  reg [2:0] first_pos, last_pos;
  reg [2:0] current_pos;
  reg [2:0] new_length;
  reg [2:0] shift_pos;
  reg [2:0] counter;
  reg [63:0] temp_str;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result_str <= 0;
      temp_str <= 0;
      first_pos <= 0;
      last_pos <= 0;
      current_pos <= 0;
      new_length <= 0;
      shift_pos <= 0;
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
        if (start) begin
          next_state = FIND_FIRST;
          temp_str = input_str;
          first_pos = 0;
          last_pos = 0;
          current_pos = 0;
          new_length = 8;
          shift_pos = 0;
          counter = 0;
        end
      end
      FIND_FIRST: begin
        if (current_pos < 8) begin
          if (temp_str[(current_pos+1)*8-1:current_pos*8] == target_char) begin
            first_pos = current_pos;
            next_state = REMOVE_FIRST;
          end else begin
            current_pos = current_pos + 1;
          end
        end else begin
          next_state = FIND_LAST;
        end
      end
      REMOVE_FIRST: begin
        if (shift_pos < 7 - first_pos) begin
          temp_str[(first_pos+shift_pos+1)*8-1:(first_pos+shift_pos)*8] = 
            temp_str[(first_pos+shift_pos+2)*8-1:(first_pos+shift_pos+1)*8];
          shift_pos = shift_pos + 1;
        end else begin
          temp_str[63:56] = 8'h00;
          new_length = 7;
          next_state = FIND_LAST;
          current_pos = 0;
          shift_pos = 0;
        end
      end
      FIND_LAST: begin
        if (current_pos < new_length) begin
          if (temp_str[(current_pos+1)*8-1:current_pos*8] == target_char) begin
            last_pos = current_pos;
            next_state = REMOVE_LAST;
          end else begin
            current_pos = current_pos + 1;
          end
        end else begin
          next_state = DONE;
        end
      end
      REMOVE_LAST: begin
        if (shift_pos < new_length - last_pos - 1) begin
          temp_str[(last_pos+shift_pos+1)*8-1:(last_pos+shift_pos)*8] = 
            temp_str[(last_pos+shift_pos+2)*8-1:(last_pos+shift_pos+1)*8];
          shift_pos = shift_pos + 1;
        end else begin
          temp_str[(last_pos+shift_pos+1)*8-1:(last_pos+shift_pos)*8] = 8'h00;
          next_state = DONE;
        end
      end
      DONE: begin
        done = 1;
        result_str = temp_str;
      end
      default: next_state = IDLE;
    endcase
  end

  // Counter for latency
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter <= 0;
    end else if (start) begin
      counter <= 0;
    end else if (counter < 18) begin
      counter <= counter + 1;
    end
  end

  // Done signal timing
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
    end else if (counter == 18) begin
      done <= 1;
    end else if (start) begin
      done <= 0;
    end
  end

endmodule