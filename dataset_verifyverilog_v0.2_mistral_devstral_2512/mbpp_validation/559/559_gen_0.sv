module max_subarray_sum (
  input clk,
  input rst_n,
  input start,
  input signed [7:0] data_in,
  input [2:0] index,
  output reg signed [7:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    LOAD,
    PROCESS,
    DONE
  } state_t;

  // Internal signals
  state_t state, next_state;
  reg signed [7:0] buffer [0:7];
  reg [2:0] load_counter;
  reg [2:0] process_counter;
  reg signed [7:0] current_sum;
  reg signed [7:0] max_sum;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      load_counter <= 0;
      process_counter <= 0;
      current_sum <= 0;
      max_sum <= 0;
      result <= 0;
      done <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = LOAD;
      end
      LOAD: begin
        if (load_counter == 7) next_state = PROCESS;
      end
      PROCESS: begin
        if (process_counter == 7) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Load counter
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      load_counter <= 0;
    end else if (state == LOAD && index == load_counter) begin
      load_counter <= load_counter + 1;
    end
  end

  // Process counter
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      process_counter <= 0;
    end else if (state == PROCESS) begin
      process_counter <= process_counter + 1;
    end
  end

  // Buffer loading
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 8; i = i + 1) begin
        buffer[i] <= 0;
      end
    end else if (state == LOAD && index == load_counter) begin
      buffer[index] <= data_in;
    end
  end

  // Kadane's algorithm computation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_sum <= 0;
      max_sum <= 0;
    end else if (state == PROCESS) begin
      if (process_counter == 0) begin
        current_sum <= buffer[0];
        max_sum <= buffer[0];
      end else begin
        current_sum <= current_sum + buffer[process_counter];
        if (current_sum < 0) begin
          current_sum <= 0;
        end
        if (current_sum > max_sum) begin
          max_sum <= current_sum;
        end
      end
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else if (state == DONE) begin
      result <= max_sum;
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule