module unique_tuples (
  input clk,
  input rst_n,
  input start,
  input [7:0] tuple_data [0:3][0:1],
  output reg [3:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    LOAD,
    COMPARE,
    COUNT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Storage for unique tuples (max 4)
  reg [7:0] stored_tuples [0:3][0:1];
  reg [3:0] unique_count;
  reg [1:0] current_tuple_index;
  reg [7:0] current_tuple [0:1];
  reg [3:0] compare_results;
  reg is_unique;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      unique_count <= 0;
      current_tuple_index <= 0;
      done <= 0;
      result <= 0;
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
        if (current_tuple_index == 3) next_state = COMPARE;
      end
      COMPARE: next_state = COUNT;
      COUNT: begin
        if (current_tuple_index == 3) next_state = DONE;
        else next_state = LOAD;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Load current tuple
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_tuple[0] <= 0;
      current_tuple[1] <= 0;
    end else if (current_state == LOAD) begin
      current_tuple[0] <= tuple_data[current_tuple_index][0];
      current_tuple[1] <= tuple_data[current_tuple_index][1];
    end
  end

  // Compare current tuple with stored tuples
  always @(*) begin
    compare_results = 0;
    is_unique = 1'b1;
    for (int i = 0; i < unique_count; i++) begin
      if (stored_tuples[i][0] == current_tuple[0] && 
          stored_tuples[i][1] == current_tuple[1]) begin
        compare_results[i] = 1'b1;
        is_unique = 1'b0;
      end
    end
  end

  // Update storage and count
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      unique_count <= 0;
      current_tuple_index <= 0;
    end else if (current_state == COUNT) begin
      if (is_unique && unique_count < 4) begin
        stored_tuples[unique_count][0] <= current_tuple[0];
        stored_tuples[unique_count][1] <= current_tuple[1];
        unique_count <= unique_count + 1;
      end
      current_tuple_index <= current_tuple_index + 1;
    end
  end

  // Output results
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else if (current_state == DONE) begin
      result <= unique_count;
      done <= 1'b1;
    end else begin
      done <= 1'b0;
    end
  end

endmodule