module largest_smallest_integers (
  input clk,
  input rst_n,
  input start,
  input [7:0][15:0] data_in,
  output reg [31:0] largest_negative,
  output reg [31:0] smallest_positive,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [2:0] counter;
  reg [15:0] current_data;

  // Constants
  parameter NONE = 32'h80000000;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      counter <= 0;
      largest_negative <= NONE;
      smallest_positive <= NONE;
      done <= 0;
    end else begin
      current_state <= next_state;
      if (current_state == PROCESSING && next_state == PROCESSING) begin
        counter <= counter + 1;
      end else if (next_state == IDLE) begin
        counter <= 0;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = PROCESSING;
      end
      PROCESSING: begin
        if (counter == 7) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Data processing
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_data <= 0;
    end else if (current_state == PROCESSING) begin
      current_data <= data_in[counter];
    end
  end

  // Processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      largest_negative <= NONE;
      smallest_positive <= NONE;
    end else if (current_state == PROCESSING) begin
      // Initialize on first cycle
      if (counter == 0) begin
        largest_negative <= NONE;
        smallest_positive <= NONE;
      end
      // Process current element
      if (current_data[15]) begin // Negative number
        if (largest_negative == NONE || $signed(current_data) > $signed(largest_negative[15:0])) begin
          largest_negative <= {{16'h0}, current_data};
        end
      end else if (current_data != 0) begin // Positive number
        if (smallest_positive == NONE || $signed(current_data) < $signed(smallest_positive[15:0])) begin
          smallest_positive <= {{16'h0}, current_data};
        end
      end
    end
  end

  // Done signal
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
    end else if (current_state == DONE) begin
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule