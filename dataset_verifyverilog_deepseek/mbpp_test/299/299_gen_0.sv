module max_aggregate (
  input clk,
  input rst_n,
  input start,
  input [2:0] student_id,
  input [7:0] marks,
  input last_entry,
  output reg [2:0] max_id,
  output reg [10:0] max_score,
  output reg done
);

  reg [10:0] accum[0:4];

  typedef enum logic [1:0] {
    IDLE,
    ACCUM,
    COMPUTE,
    DONE
  } state_t;

  state_t current_state, next_state;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      accum[0] <= '0;
      accum[1] <= '0;
      accum[2] <= '0;
      accum[3] <= '0;
      accum[4] <= '0;
      max_id <= '0;
      max_score <= '0;
      done <= '0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          if (start) begin
            accum[0] <= 0;
            accum[1] <= 0;
            accum[2] <= 0;
            accum[3] <= 0;
            accum[4] <= 0;
          end
        end

        ACCUM: begin
          if (student_id <= 4) begin
            accum[student_id] <= accum[student_id] + marks;
          end
        end

        COMPUTE: begin
          max_score <= accum[0];
          max_id <= 0;
          for (int i = 1; i <= 4; i++) begin
            if (accum[i] > max_score) begin
              max_score <= accum[i];
              max_id <= i;
            end
          end
        end

        DONE: begin
          // No operations - output handled via done signal
        end
      endcase
    end
  end

  always_comb begin
    done = 0;
    next_state = current_state;
    case (current_state)
      IDLE: if (start) next_state = ACCUM;
      ACCUM: if (last_entry) next_state = COMPUTE;
      COMPUTE: next_state = DONE;
      DONE: begin
        done = 1;
        next_state = IDLE;
      end
    endcase
  end
endmodule