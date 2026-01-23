module newman_prime (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t state, next_state;
  reg [15:0] prev, curr;
  reg [31:0] next_val; // 32-bit to prevent overflow
  reg [3:0] counter;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 16'b0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = PROCESSING;
      end
      PROCESSING: begin
        if (counter == n) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      prev <= 16'b0;
      curr <= 16'b0;
      counter <= 4'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            prev <= 16'd1; // a0 = 1
            curr <= 16'd1; // a1 = 1
            counter <= 4'd0;
          end
        end
        PROCESSING: begin
          if (counter < n) begin
            next_val = 32'd2 * curr + prev;
            prev <= curr;
            curr <= next_val[15:0]; // Truncate to 16 bits
            counter <= counter + 1;
          end
        end
        DONE: begin
          result <= curr;
          done <= 1'b1;
        end
      endcase
    end
  end

  // Reset done signal when leaving DONE state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
    end else if (state == DONE && !start) begin
      done <= 1'b0;
    end
  end

endmodule