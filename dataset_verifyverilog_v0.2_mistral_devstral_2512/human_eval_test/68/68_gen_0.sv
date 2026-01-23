module pluck_module (
  input clk,
  input rst_n,
  input start,
  input [15:0] arr_in,
  input [3:0] arr_index,
  input valid_in,
  input last_in,
  output reg [31:0] result,
  output reg done,
  output reg ready
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COLLECT,
    FINALIZE,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [15:0] smallest_value;
  reg [3:0] smallest_index;
  reg found;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      smallest_value <= 16'hFFFF;
      smallest_index <= 4'b0;
      found <= 1'b0;
      result <= 32'b0;
      done <= 1'b0;
      ready <= 1'b1;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = COLLECT;
        else next_state = IDLE;
      end
      COLLECT: begin
        if (last_in) next_state = FINALIZE;
        else next_state = COLLECT;
      end
      FINALIZE: next_state = DONE;
      DONE: begin
        if (!start) next_state = IDLE;
        else next_state = DONE;
      end
    endcase
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ready <= 1'b1;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          ready <= 1'b1;
          done <= 1'b0;
        end
        COLLECT: begin
          ready <= 1'b1;
          done <= 1'b0;
        end
        FINALIZE: begin
          ready <= 1'b0;
          done <= 1'b1;
        end
        DONE: begin
          ready <= 1'b0;
          done <= 1'b1;
        end
      endcase
    end
  end

  // Data processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      smallest_value <= 16'hFFFF;
      smallest_index <= 4'b0;
      found <= 1'b0;
    end else if (state == COLLECT && valid_in) begin
      if (arr_in[0] == 1'b0) begin // Check if even
        if (!found || (arr_in < smallest_value) || (arr_in == smallest_value && arr_index < smallest_index)) begin
          smallest_value <= arr_in;
          smallest_index <= arr_index;
          found <= 1'b1;
        end
      end
    end
  end

  // Result computation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 32'b0;
    end else if (state == FINALIZE) begin
      if (found) begin
        result <= {smallest_index, smallest_value};
      end else begin
        result <= 32'b0;
      end
    end
  end

endmodule