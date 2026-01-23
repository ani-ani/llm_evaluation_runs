module text_match_two_three (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input [2:0] char_index,
  output reg match,
  output reg done
);

  // Define states
  typedef enum logic [3:0] {
    IDLE,
    SEARCH_A,
    FOUND_A1,
    FOUND_AB,
    FOUND_ABB,
    FOUND_ABBB,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [2:0] counter;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      match <= 1'b0;
      done <= 1'b0;
      counter <= 3'd0;
    end else begin
      current_state <= next_state;
      if (next_state == DONE) begin
        done <= 1'b1;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = SEARCH_A;
          counter = 3'd0;
          match = 1'b0;
          done = 1'b0;
        end
      end
      SEARCH_A: begin
        if (char_in == 8'h61) begin
          next_state = FOUND_A1;
        end
      end
      FOUND_A1: begin
        if (char_in == 8'h62) begin
          next_state = FOUND_AB;
        end else if (char_in == 8'h61) begin
          next_state = FOUND_A1;
        end else begin
          next_state = SEARCH_A;
        end
      end
      FOUND_AB: begin
        if (char_in == 8'h62) begin
          next_state = FOUND_ABB;
        end else if (char_in == 8'h61) begin
          next_state = FOUND_A1;
        end else begin
          next_state = SEARCH_A;
        end
      end
      FOUND_ABB: begin
        if (char_in == 8'h62) begin
          next_state = FOUND_ABBB;
        end else if (char_in == 8'h61) begin
          next_state = FOUND_A1;
        end else begin
          next_state = SEARCH_A;
        end
      end
      FOUND_ABBB: begin
        if (char_in == 8'h61) begin
          next_state = FOUND_A1;
        end else begin
          next_state = SEARCH_A;
        end
      end
      DONE: begin
        next_state = DONE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Match detection
  always @(*) begin
    case (current_state)
      FOUND_ABB, FOUND_ABBB: match = 1'b1;
      default: match = 1'b0;
    endcase
  end

  // Counter for done signal
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter <= 3'd0;
    end else if (start) begin
      counter <= 3'd0;
    end else if (current_state != DONE && current_state != IDLE) begin
      if (char_index == 3'd7) begin
        counter <= 3'd7;
      end else begin
        counter <= char_index;
      end
    end
  end

  // Done signal
  always @(*) begin
    if (counter == 3'd7 && current_state != DONE && current_state != IDLE) begin
      done = 1'b1;
      next_state = DONE;
    end else if (current_state == DONE) begin
      done = 1'b1;
    end else begin
      done = 1'b0;
    end
  end

endmodule