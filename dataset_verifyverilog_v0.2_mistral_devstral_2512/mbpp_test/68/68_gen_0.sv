module is_monotonic #(
  parameter N = 8
)(
  input clk,
  input rst_n,
  input start,
  input [7:0] data_in,
  input [2:0] index,
  output reg result,
  output reg done
);

  // Internal storage for array
  reg [7:0] array_reg [0:N-1];

  // State machine
  typedef enum logic [1:0] {
    IDLE,
    LOADING,
    PROCESSING,
    DONE
  } state_t;
  state_t current_state, next_state;

  // Control signals
  reg [2:0] load_counter;
  reg [2:0] process_counter;
  reg inc_flag, dec_flag;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      load_counter <= 0;
      process_counter <= 0;
      inc_flag <= 1;
      dec_flag <= 1;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = LOADING;
      end
      LOADING: begin
        if (load_counter == N-1) next_state = PROCESSING;
      end
      PROCESSING: begin
        if (process_counter == N-2) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Loading logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      load_counter <= 0;
    end else if (current_state == LOADING && start) begin
      array_reg[index] <= data_in;
      if (index == load_counter) load_counter <= load_counter + 1;
    end
  end

  // Processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      process_counter <= 0;
      inc_flag <= 1;
      dec_flag <= 1;
    end else if (current_state == PROCESSING) begin
      if (process_counter < N-1) begin
        if (array_reg[process_counter] > array_reg[process_counter+1]) inc_flag = 0;
        if (array_reg[process_counter] < array_reg[process_counter+1]) dec_flag = 0;
        process_counter <= process_counter + 1;
      end
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else begin
      if (current_state == PROCESSING && process_counter == N-2) begin
        result <= inc_flag || dec_flag;
      end
      done <= (current_state == DONE);
    end
  end

endmodule