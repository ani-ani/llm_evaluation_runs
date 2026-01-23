module digit_sum_to_binary (
  input clk,
  input rst_n,
  input start,
  input [7:0] N,
  output reg [3:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CALCULATE_SUM,
    CONVERT_BINARY,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] ones, tens, hundreds;
  reg [3:0] decimal_sum;
  reg [3:0] cycle_count;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 4'b0;
      done <= 1'b0;
      ones <= 8'b0;
      tens <= 8'b0;
      hundreds <= 8'b0;
      decimal_sum <= 4'b0;
      cycle_count <= 4'b0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = CALCULATE_SUM;
      end
      CALCULATE_SUM: begin
        if (cycle_count == 3'd2) next_state = CONVERT_BINARY;
      end
      CONVERT_BINARY: begin
        if (cycle_count == 3'd6) next_state = DONE;
      end
      DONE: begin
        if (start) next_state = CALCULATE_SUM;
        else next_state = IDLE;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ones <= 8'b0;
      tens <= 8'b0;
      hundreds <= 8'b0;
      decimal_sum <= 4'b0;
      cycle_count <= 4'b0;
    end else begin
      case (current_state)
        IDLE: begin
          ones <= 8'b0;
          tens <= 8'b0;
          hundreds <= 8'b0;
          decimal_sum <= 4'b0;
          cycle_count <= 4'b0;
          done <= 1'b0;
        end
        CALCULATE_SUM: begin
          if (cycle_count == 3'd0) begin
            ones <= N % 10;
            tens <= (N / 10) % 10;
            hundreds <= (N / 100) % 10;
          end else if (cycle_count == 3'd1) begin
            decimal_sum <= ones + tens + hundreds;
          end
          cycle_count <= cycle_count + 1'b1;
        end
        CONVERT_BINARY: begin
          if (cycle_count == 3'd3) begin
            result <= decimal_sum;
          end
          cycle_count <= cycle_count + 1'b1;
        end
        DONE: begin
          done <= 1'b1;
        end
      endcase
    end
  end

endmodule