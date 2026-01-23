module phone_numbers (
  input clk,
  input rst_n,
  input start,
  input [99:0] digit_vector,
  output reg [3:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COUNTING,
    CALCULATING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Counters
  reg [7:0] count_eights;
  reg [15:0] total_cards;
  reg [15:0] temp_count;

  // Control signals
  reg [7:0] counter;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      count_eights <= 0;
      total_cards <= 0;
      temp_count <= 0;
      counter <= 0;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          if (start) begin
            count_eights <= 0;
            total_cards <= 0;
            temp_count <= 0;
            counter <= 0;
          end
        end

        COUNTING: begin
          if (counter < 100) begin
            if (digit_vector[counter]) begin
              temp_count <= temp_count + 1;
              if (counter == 8) begin
                count_eights <= count_eights + 1;
              end
            end
            counter <= counter + 1;
          end
        end

        CALCULATING: begin
          total_cards <= temp_count;
          result <= (count_eights < (total_cards / 11)) ? count_eights : (total_cards / 11);
        end

        DONE: begin
          done <= 1;
        end

        default: begin
          current_state <= IDLE;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = COUNTING;
      end

      COUNTING: begin
        if (counter == 100) next_state = CALCULATING;
      end

      CALCULATING: begin
        next_state = DONE;
      end

      DONE: begin
        if (!start) next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule