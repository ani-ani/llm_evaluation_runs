module max_points_game (
  input clk,
  input rst_n,
  input start,
  input [7:0] sequence_in,
  input load_valid,
  output reg [15:0] max_score,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    LOAD,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Load counter
  reg [3:0] load_count;

  // LUT for counts (0-255)
  reg [7:0] count [0:255];

  // Processing variables
  reg [7:0] i;
  reg [15:0] dp_i, dp_i_minus_1, dp_i_minus_2;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      load_count <= 0;
      i <= 0;
      dp_i <= 0;
      dp_i_minus_1 <= 0;
      dp_i_minus_2 <= 0;
      max_score <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;

      // State-specific registers
      case (current_state)
        IDLE: begin
          if (start) begin
            load_count <= 0;
            i <= 0;
            dp_i <= 0;
            dp_i_minus_1 <= 0;
            dp_i_minus_2 <= 0;
            max_score <= 0;
            done <= 0;
          end
        end
        LOAD: begin
          if (load_valid) begin
            count[sequence_in] <= count[sequence_in] + 1;
            load_count <= load_count + 1;
          end
        end
        PROCESSING: begin
          if (i == 0) begin
            dp_i <= 0;
            dp_i_minus_1 <= 0;
            dp_i_minus_2 <= 0;
          end else if (i == 1) begin
            dp_i <= count[1] * 1;
            dp_i_minus_1 <= dp_i;
            dp_i_minus_2 <= 0;
          end else begin
            dp_i <= (dp_i_minus_1 > (dp_i_minus_2 + count[i] * i)) ? dp_i_minus_1 : (dp_i_minus_2 + count[i] * i);
            dp_i_minus_2 <= dp_i_minus_1;
            dp_i_minus_1 <= dp_i;
          end
          i <= i + 1;
        end
        DONE: begin
          max_score <= dp_i;
          done <= 1;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = LOAD;
      end
      LOAD: begin
        if (load_count == 15) next_state = PROCESSING;
      end
      PROCESSING: begin
        if (i == 255) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

endmodule