module strlen (
  input clk,
  input rst_n,
  input start,
  input [127:0] string_data,
  output reg [3:0] length,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SCANNING,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [3:0] byte_index;
  reg [7:0] current_byte;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      length <= 0;
      done <= 0;
      byte_index <= 0;
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
          next_state = SCANNING;
          length = 0;
          byte_index = 0;
          done = 0;
        end
      end
      SCANNING: begin
        // Extract current byte
        current_byte = string_data[(byte_index + 1) * 8 - 1 : byte_index * 8];
        
        if (current_byte == 8'h00 || byte_index == 15) begin
          next_state = DONE;
          done = 1;
        end else begin
          next_state = SCANNING;
          byte_index = byte_index + 1;
          length = length + 1;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
          done = 0;
        end
      end
    endcase
  end

endmodule