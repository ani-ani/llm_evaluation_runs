module swap_list (
  input clk,
  input rst_n,
  input start,
  input [2:0] size,
  input [7:0] arr_in [0:7],
  output reg [7:0] arr_out [0:7],
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    case (current_state)
      IDLE: begin
        if (start) next_state = PROCESSING;
        else next_state = IDLE;
      end
      PROCESSING: next_state = DONE;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      for (int i = 0; i < 8; i = i + 1) begin
        arr_out[i] <= 8'b0;
      end
    end else begin
      case (current_state)
        IDLE: begin
          done <= 1'b0;
        end
        PROCESSING: begin
          // Copy all elements from arr_in to arr_out
          for (int i = 0; i < 8; i = i + 1) begin
            arr_out[i] <= arr_in[i];
          end
          // Swap first and last elements if size >= 2
          if (size >= 2) begin
            arr_out[0] <= arr_in[size-1];
            arr_out[size-1] <= arr_in[0];
          end
          done <= 1'b0;
        end
        DONE: begin
          done <= 1'b1;
        end
        default: begin
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule