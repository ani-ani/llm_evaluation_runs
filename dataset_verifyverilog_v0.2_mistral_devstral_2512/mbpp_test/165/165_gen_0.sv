module count_char_position (
  input clk,
  input rst_n,
  input start,
  input [63:0] str_data,
  output reg [2:0] count,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [2:0] position;
  reg [7:0] current_char;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      count <= 3'b0;
      position <= 3'b0;
      done <= 1'b0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = PROCESSING;
        else next_state = IDLE;
      end
      PROCESSING: begin
        if (position == 7) next_state = DONE;
        else next_state = PROCESSING;
      end
      DONE: next_state = IDLE;
    endcase
  end

  // Processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      position <= 3'b0;
      count <= 3'b0;
    end else if (current_state == PROCESSING) begin
      // Extract current character
      current_char = str_data[(position * 8) +: 8];
      
      // Check if character matches position (case insensitive)
      if ((current_char == ("A" + position)) || 
          (current_char == ("a" + position))) begin
        count <= count + 1;
      end
      
      // Move to next position
      if (position == 7) begin
        position <= 3'b0;
      end else begin
        position <= position + 1;
      end
    end else if (current_state == DONE) begin
      done <= 1'b1;
    end else begin
      done <= 1'b0;
    end
  end

endmodule