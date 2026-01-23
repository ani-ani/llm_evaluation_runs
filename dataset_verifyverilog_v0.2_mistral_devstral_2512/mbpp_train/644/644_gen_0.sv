module reverse_array_upto_k (
  input clk,
  input rst_n,
  input start,
  input [2:0] k,
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

  // Internal registers
  reg [2:0] left_ptr;
  reg [2:0] right_ptr;
  reg [2:0] swap_count;
  reg [2:0] cycle_count;

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      left_ptr <= 3'b0;
      right_ptr <= 3'b0;
      swap_count <= 3'b0;
      cycle_count <= 3'b0;
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
          next_state = PROCESSING;
        end
      end
      PROCESSING: begin
        if (cycle_count == 3'd7) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

  // Output array initialization and processing
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 8; i = i + 1) begin
        arr_out[i] <= 8'b0;
      end
    end else begin
      case (current_state)
        IDLE: begin
          if (start) begin
            for (int i = 0; i < 8; i = i + 1) begin
              arr_out[i] <= arr_in[i];
            end
            left_ptr <= 3'b0;
            right_ptr <= k - 1'b1;
            swap_count <= 3'b0;
            cycle_count <= 3'b0;
          end
        end
        PROCESSING: begin
          if (cycle_count < 3'd7) begin
            if (left_ptr < right_ptr) begin
              // Swap elements
              reg [7:0] temp;
              temp = arr_out[left_ptr];
              arr_out[left_ptr] = arr_out[right_ptr];
              arr_out[right_ptr] = temp;
              left_ptr <= left_ptr + 1'b1;
              right_ptr <= right_ptr - 1'b1;
            end
            cycle_count <= cycle_count + 1'b1;
          end
        end
        DONE: begin
          done <= 1'b1;
        end
      endcase
    end
  end

  // Reset done signal when leaving DONE state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
    end else if (current_state == DONE && !start) begin
      done <= 1'b0;
    end
  end

endmodule