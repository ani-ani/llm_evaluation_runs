module syllable_checker(
  input clk,
  input rst_n,
  input start,
  input [7:0] pattern,
  input [127:0] line,
  output reg match,
  output reg done
);

  // States
  typedef enum logic [1:0] {
    IDLE,
    CHECK_CHAR,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [7:0] vowel_count;
  reg [3:0] char_index;
  reg [7:0] current_char;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      vowel_count <= 8'd0;
      char_index <= 4'd0;
      match <= 1'b0;
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
        if (start) next_state = CHECK_CHAR;
      end
      CHECK_CHAR: begin
        if (char_index == 4'd15) next_state = DONE;
      end
      DONE: begin
        next_state = IDLE;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      vowel_count <= 8'd0;
      char_index <= 4'd0;
    end else begin
      case (current_state)
        IDLE: begin
          vowel_count <= 8'd0;
          char_index <= 4'd0;
        end
        CHECK_CHAR: begin
          current_char = line[(char_index + 1) * 8 - 1 : char_index * 8];
          if (current_char == 8'h61 || // 'a'
              current_char == 8'h65 || // 'e'
              current_char == 8'h69 || // 'i'
              current_char == 8'h6F || // 'o'
              current_char == 8'h75 || // 'u'
              current_char == 8'h79)   // 'y'
            vowel_count <= vowel_count + 1;
          char_index <= char_index + 1;
        end
        DONE: begin
          match <= (vowel_count == pattern);
          done <= 1'b1;
        end
      endcase
    end
  end

  // Reset done signal after one cycle
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
    end else if (current_state == DONE) begin
      done <= 1'b0;
    end
  end

endmodule