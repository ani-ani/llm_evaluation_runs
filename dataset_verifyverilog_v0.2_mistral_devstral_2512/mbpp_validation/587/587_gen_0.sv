module list_to_tuple (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_elements,
  input [7:0] list_in [0:7],
  output reg [7:0] tuple_out [0:7],
  output reg done,
  output reg valid
);

  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      valid <= 1'b0;
    end else begin
      current_state <= next_state;
    end
  end

  always @(*) begin
    next_state = current_state;
    done = 1'b0;
    valid = 1'b0;

    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
        end
      end

      PROCESSING: begin
        next_state = DONE;
        for (int i = 0; i < 8; i = i + 1) begin
          if (i < num_elements) begin
            tuple_out[i] = list_in[i];
          end else begin
            tuple_out[i] = 8'b0;
          end
        end
      end

      DONE: begin
        done = 1'b1;
        valid = 1'b1;
        if (start) begin
          next_state = PROCESSING;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule