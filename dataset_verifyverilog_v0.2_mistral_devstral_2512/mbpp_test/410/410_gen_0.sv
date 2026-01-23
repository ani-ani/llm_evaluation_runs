module min_heterogeneous (
  input clk,
  input rst_n,
  input start,
  input [2:0] count,
  input [7:0] data_in,
  input load,
  output reg [7:0] min_result,
  output reg done,
  output reg error
);

  // Define states
  typedef enum logic [1:0] {
    IDLE,
    LOAD,
    PROCESSING,
    DONE
  } state_t;

  // State register
  state_t current_state, next_state;

  // Internal array to store data
  reg [7:0] data_array [0:7];

  // Counters and control signals
  reg [2:0] load_counter;
  reg [2:0] process_counter;
  reg [7:0] current_min;

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      load_counter <= 0;
      process_counter <= 0;
      current_min <= 8'hFF;
      min_result <= 8'h0;
      done <= 0;
      error <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = LOAD;
      end
      LOAD: begin
        if (load_counter == count - 1) next_state = PROCESSING;
      end
      PROCESSING: begin
        if (process_counter == count - 1) next_state = DONE;
      end
      DONE: begin
        if (start) next_state = LOAD;
      end
      default: next_state = IDLE;
    endcase
  end

  // Load data into array
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      load_counter <= 0;
    end else if (current_state == LOAD && load) begin
      data_array[load_counter] <= data_in;
      load_counter <= load_counter + 1;
    end
  end

  // Process data to find minimum
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      process_counter <= 0;
      current_min <= 8'hFF;
    end else if (current_state == PROCESSING) begin
      if (data_array[process_counter] != 8'hFF) begin
        if (current_min == 8'hFF || data_array[process_counter] < current_min) begin
          current_min <= data_array[process_counter];
        end
      end
      process_counter <= process_counter + 1;
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      min_result <= 8'h0;
      done <= 0;
      error <= 0;
    end else begin
      case (current_state)
        DONE: begin
          min_result <= current_min;
          done <= 1;
          error <= (current_min == 8'hFF);
        end
        default: begin
          done <= 0;
          error <= 0;
        end
      endcase
    end
  end

endmodule