module remove_consecutive_duplicates (
  input clk,
  input rst_n,
  input start,
  input [4:0] input_length,
  input [7:0] input_data [15:0],
  output reg [4:0] output_length,
  output reg [7:0] output_data [15:0],
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  // State register
  state_t state_reg, state_next;

  // Internal registers
  reg [3:0] index_reg, index_next;
  reg [7:0] prev_data_reg, prev_data_next;
  reg [4:0] count_reg, count_next;

  // Default assignments
  assign output_length = count_reg;
  assign done = (state_reg == DONE);

  // State transition logic
  always_comb begin
    state_next = state_reg;
    index_next = index_reg;
    prev_data_next = prev_data_reg;
    count_next = count_reg;

    case (state_reg)
      IDLE: begin
        if (!rst_n) begin
          state_next = IDLE;
          index_next = 0;
          prev_data_next = 0;
          count_next = 0;
        end else if (start) begin
          state_next = PROCESSING;
          index_next = 0;
          prev_data_next = 0;
          count_next = 0;
        end
      end

      PROCESSING: begin
        if (index_reg == 0) begin
          // First element is always included
          output_data[index_reg] = input_data[index_reg];
          prev_data_next = input_data[index_reg];
          count_next = 1;
          index_next = index_reg + 1;
        end else if (index_reg < input_length) begin
          if (input_data[index_reg] != prev_data_reg) begin
            // Different from previous, include in output
            output_data[count_reg] = input_data[index_reg];
            prev_data_next = input_data[index_reg];
            count_next = count_reg + 1;
          end
          index_next = index_reg + 1;
        end else begin
          // Processing complete
          state_next = DONE;
        end
      end

      DONE: begin
        if (!rst_n) begin
          state_next = IDLE;
          index_next = 0;
          prev_data_next = 0;
          count_next = 0;
        end
      end
    endcase
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_reg <= IDLE;
      index_reg <= 0;
      prev_data_reg <= 0;
      count_reg <= 0;
      done <= 0;
    end else begin
      state_reg <= state_next;
      index_reg <= index_next;
      prev_data_reg <= prev_data_next;
      count_reg <= count_next;
      done <= (state_next == DONE);
    end
  end

endmodule