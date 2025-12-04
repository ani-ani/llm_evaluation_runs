module eurus_function(
  input clk,
  input rst_n,
  input start,
  input [15:0] n,
  input [7:0] k,
  output reg [15:0] result,
  output reg done
);

  // State definition
  typedef enum logic [0:0] {IDLE, COMPUTE} state_t;
  state_t state;

  // Internal signals
  reg [15:0] current_value;
  reg [4:0] steps_counter;
  wire [15:0] totient_out;

  // ROM instantiation
  rom_totient rom_inst(
    .addr(current_value),
    .data(totient_out)
  );

  // Steps calculation
  wire [4:0] max_steps = (k + 1) >> 1;
  wire [4:0] steps_limit = (max_steps > 16) ? 5'd16 : max_steps[4:0];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 16'b0;
      done <= 1'b0;
      current_value <= 16'b0;
      steps_counter <= 5'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            done <= 1'b0;
            current_value <= n;
            steps_counter <= steps_limit;
            state <= COMPUTE;
          end
        end

        COMPUTE: begin
          if (steps_counter != 0 && current_value != 16'd1) begin
            current_value <= totient_out;
            steps_counter <= steps_counter - 1'b1;
          end else begin
            result <= current_value;
            done <= 1'b1;
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule

// ROM module declaration
module rom_totient(
  input  [15:0] addr,
  output reg [15:0] data
);
  // Content omitted - precomputed Φ values
endmodule