module sum_range_list (
  input clk,
  input rst_n,
  input start,
  input [3:0] m,
  input [3:0] n,
  input [7:0] list1 [11:0],
  output reg [10:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t state, next_state;
  reg [3:0] current_index;
  reg [10:0] running_sum;
  reg [3:0] counter;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_index <= 0;
      running_sum <= 0;
      counter <= 0;
      result <= 0;
      done <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = PROCESSING;
        else next_state = IDLE;
      end
      PROCESSING: begin
        if (counter == 11) next_state = DONE;
        else next_state = PROCESSING;
      end
      DONE: begin
        if (!start) next_state = IDLE;
        else next_state = DONE;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_index <= 0;
      running_sum <= 0;
      counter <= 0;
    end else begin
      case (state)
        IDLE: begin
          current_index <= m;
          running_sum <= 0;
          counter <= 0;
        end
        PROCESSING: begin
          if (counter < 12) begin
            if (current_index <= n) begin
              running_sum <= running_sum + list1[current_index];
              current_index <= current_index + 1;
            end
            counter <= counter + 1;
          end
        end
        DONE: begin
          result <= running_sum;
          done <= 1;
        end
      endcase
    end
  end

endmodule