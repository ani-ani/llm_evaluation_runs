module pack_duplicates (
  input clk,
  input rst_n,
  input start,
  input [3:0] length,
  input [15:0] data_in [0:15],
  output reg [3:0] group_starts [0:15],
  output reg [3:0] group_lengths [0:15],
  output reg [3:0] num_groups,
  output reg done
);

  // State machine states
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [3:0] index;
  reg [3:0] current_group_start;
  reg [3:0] current_group_length;
  reg [3:0] group_count;
  reg [15:0] prev_data;

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      index <= 0;
      current_group_start <= 0;
      current_group_length <= 0;
      group_count <= 0;
      prev_data <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;

      // State transitions
      case (current_state)
        IDLE: begin
          if (start) begin
            index <= 0;
            current_group_start <= 0;
            current_group_length <= 0;
            group_count <= 0;
            prev_data <= 0;
            done <= 0;
            next_state <= PROCESSING;
          end else begin
            next_state <= IDLE;
          end
        end

        PROCESSING: begin
          if (index == length - 1) begin
            // Last element, finalize current group
            group_starts[group_count] <= current_group_start;
            group_lengths[group_count] <= current_group_length + 1;
            group_count <= group_count + 1;
            num_groups <= group_count + 1;
            done <= 1;
            next_state <= DONE;
          end else begin
            // Process next element
            if (data_in[index] == prev_data) begin
              current_group_length <= current_group_length + 1;
            end else begin
              // New group detected
              group_starts[group_count] <= current_group_start;
              group_lengths[group_count] <= current_group_length + 1;
              group_count <= group_count + 1;
              current_group_start <= index + 1;
              current_group_length <= 0;
            end
            prev_data <= data_in[index];
            index <= index + 1;
          end
        end

        DONE: begin
          if (!start) begin
            next_state <= IDLE;
            done <= 0;
          end else begin
            next_state <= DONE;
          end
        end
      endcase
    end
  end

  // Default assignments for outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      num_groups <= 0;
      done <= 0;
      for (int i = 0; i < 16; i++) begin
        group_starts[i] <= 0;
        group_lengths[i] <= 0;
      end
    end
  end

endmodule