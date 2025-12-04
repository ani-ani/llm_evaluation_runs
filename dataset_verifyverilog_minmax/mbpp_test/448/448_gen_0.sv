module perrin_sum (
  input clk,         // clock
  input rst_n,       // active-low reset
  input start,       // pulse high to start computation
  input [7:0] n,     // input value (0-255)
  output reg [31:0] sum, // 32-bit sum result
  output reg done    // high when computation complete
);

  // State machine states
  localparam IDLE = 2'd0;
  localparam RUN  = 2'd1;
  localparam DONE = 2'd2;

  // Internal state registers
  reg [7:0] n_reg;      // registered input n
  reg [31:0] a_reg, b_reg, c_reg, sum_reg; // iterative calculation registers
  reg [7:0] counter;    // iteration counter
  reg [1:0] state;      // state machine state
  wire [31:0] d;        // next Perrin number (combinational)

  // Compute next Perrin number
  assign d = a_reg + b_reg;

  // State machine and sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all internal state
      state <= IDLE;
      sum <= 0;
      done <= 0;
      n_reg <= 0;
      a_reg <= 0;
      b_reg <= 0;
      c_reg <= 0;
      sum_reg <= 0;
      counter <= 0;
    end
    else begin
      case (state)
        IDLE: begin
          if (start) begin
            n_reg <= n;  // capture input n
            if (n > 2) begin
              // Initialize for n > 2
              a_reg <= 3;
              b_reg <= 0;
              c_reg <= 2;
              sum_reg <= 5;  // Initial sum
              counter <= n - 2;  // Number of iterations
            end
            else begin
              // For n <= 2, counter is not used
              counter <= 0;
            end
            state <= RUN;
            done <= 0;  // Ensure done is low during computation
          end
        end

        RUN: begin
          if (n_reg <= 2) begin
            // Handle n = 0, 1, 2 cases
            if (n_reg == 0 || n_reg == 1) 
              sum <= 32'h3;  // P(0)=3, P(1)=3
            else if (n_reg == 2)
              sum <= 32'h5;  // P(2)=5
            done <= 1;
            state <= DONE;
          end
          else begin
            if (counter > 0) begin
              // Iterative calculation
              sum_reg <= sum_reg + d;  // Add next Perrin number
              a_reg <= b_reg;          // Shift registers
              b_reg <= c_reg;
              c_reg <= d;
              counter <= counter - 1;
            end
            else begin
              // Counter is zero - computation complete
              sum <= sum_reg;  // Output final sum
              done <= 1;
              state <= DONE;
            end
          end
        end

        DONE: begin
          done <= 1;  // Maintain done signal
          if (!start) 
            state <= IDLE;  // Return to idle when start is low
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule