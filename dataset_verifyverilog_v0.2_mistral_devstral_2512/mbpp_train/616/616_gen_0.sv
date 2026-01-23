module tuple_modulo (
  input clk,
  input rst_n,
  input start,
  input [7:0] tuple1 [0:3],
  input [7:0] tuple2 [0:3],
  output reg [7:0] result [0:3],
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    LOAD,
    COMPUTE,
    STORE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [1:0] element_idx; // Index for current element (0-3)
  reg [7:0] dividend, divisor; // Current element values
  reg [7:0] remainder; // Remainder during computation
  reg [7:0] subtract_counter; // Counter for subtraction iterations
  reg [3:0] compute_cycles; // Counter for compute cycles per element

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      element_idx <= 0;
      done <= 0;
      for (int i = 0; i < 4; i++) begin
        result[i] <= 0;
      end
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
        else next_state = IDLE;
      end
      LOAD: next_state = COMPUTE;
      COMPUTE: begin
        if (subtract_counter == 0 || remainder < divisor) next_state = STORE;
        else next_state = COMPUTE;
      end
      STORE: begin
        if (element_idx == 3) next_state = DONE;
        else next_state = LOAD;
      end
      DONE: begin
        if (!start) next_state = IDLE;
        else next_state = DONE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      element_idx <= 0;
      dividend <= 0;
      divisor <= 0;
      remainder <= 0;
      subtract_counter <= 0;
      compute_cycles <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          element_idx <= 0;
          done <= 0;
        end
        LOAD: begin
          dividend <= tuple1[element_idx];
          divisor <= tuple2[element_idx];
          remainder <= dividend;
          subtract_counter <= 0;
          compute_cycles <= 0;
        end
        COMPUTE: begin
          if (divisor != 0 && remainder >= divisor) begin
            remainder <= remainder - divisor;
            subtract_counter <= subtract_counter + 1;
          end
          compute_cycles <= compute_cycles + 1;
        end
        STORE: begin
          result[element_idx] <= remainder;
          if (element_idx == 3) begin
            done <= 1;
          end else begin
            element_idx <= element_idx + 1;
          end
        end
        DONE: begin
          // Hold state until reset
        end
        default: ;
      endcase
    end
  end

endmodule