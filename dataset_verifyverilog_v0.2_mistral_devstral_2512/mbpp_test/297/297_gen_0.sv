module flatten_list(
  input clk,
  input rst_n,
  input start,
  input [3:0] num_subarrays,
  input [3:0] subarray_lengths [0:3],
  input [7:0] data_in [0:15],
  output reg [7:0] flattened [0:15],
  output reg [4:0] output_length,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    READING,
    WRITING,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [3:0] subarray_idx;
  reg [3:0] element_idx;
  reg [3:0] output_idx;
  reg [4:0] total_length;
  reg [3:0] cycle_count;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      subarray_idx <= 0;
      element_idx <= 0;
      output_idx <= 0;
      total_length <= 0;
      cycle_count <= 0;
      done <= 0;
      output_length <= 0;
    end else begin
      current_state <= next_state;
      if (next_state == READING) begin
        if (element_idx < subarray_lengths[subarray_idx]) begin
          element_idx <= element_idx + 1;
        end else begin
          element_idx <= 0;
          subarray_idx <= subarray_idx + 1;
        end
      end else if (next_state == WRITING) begin
        output_idx <= output_idx + 1;
        cycle_count <= cycle_count + 1;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = READING;
          total_length = 0;
          for (int i = 0; i < num_subarrays; i++) begin
            total_length = total_length + subarray_lengths[i];
          end
          output_length = total_length;
        end
      end
      READING: begin
        if (subarray_idx < num_subarrays) begin
          if (element_idx < subarray_lengths[subarray_idx]) begin
            next_state = WRITING;
          end
        end else begin
          next_state = DONE;
        end
      end
      WRITING: begin
        if (cycle_count < 15) begin
          next_state = READING;
        end else begin
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

  // Output logic
  always @(*) begin
    case (current_state)
      IDLE: begin
        done = 0;
        for (int i = 0; i < 16; i++) begin
          flattened[i] = 0;
        end
      end
      READING: begin
        done = 0;
      end
      WRITING: begin
        done = 0;
        flattened[output_idx] = data_in[element_idx + (subarray_idx * 4)];
      end
      DONE: begin
        done = 1;
      end
    endcase
  end

endmodule