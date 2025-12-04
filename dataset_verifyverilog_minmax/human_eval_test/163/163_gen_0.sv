module even_digit_filter (
  input clk,
  input rst_n,
  input reg start,
  input reg [7:0] a,
  input reg [7:0] b,
  output reg [3:0][7:0] result_array,
  output reg [1:0] valid_count,
  output reg done
);

  // Internal state and datapath
  typedef enum logic [1:0] { IDLE = 2'b00, RUN = 2'b01, DONE = 2'b10 } fsm_state_t;
  fsm_state_t state;

  reg [7:0] min_val, max_val;
  reg [8:0] total_steps; // up to 256
  reg [8:0] steps;       // current step counter
  reg [1:0] write_index; // 0..3 for result_array
  reg [7:0] current;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all outputs and internal state
      result_array  <= '0;
      valid_count   <= 2'd0;
      done          <= 1'b0;
      state         <= IDLE;
      min_val       <= 8'd0;
      max_val       <= 8'd0;
      total_steps   <= 9'd0;
      steps         <= 9'd0;
      write_index   <= 2'd0;
      current       <= 8'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          // Start on a rising start pulse (or when start becomes 1)
          if (start) begin
            min_val <= (a < b) ? a : b;
            max_val <= (a < b) ? b : a;
            valid_count <= 2'd0;
            write_index <= 2'd0;
            result_array <= '0;
            // total_steps = max_val - min_val + 1; safe up to 256
            total_steps <= (max_val >= min_val) ? ({1'b0, max_val} - {1'b0, min_val} + 9'd1) : 9'd0;
            steps <= 9'd0;
            current <= min_val;
            state <= RUN;
          end else begin
            state <= IDLE;
          end
        end

        RUN: begin
          if (steps < total_steps) begin
            // Check conditions: single digit (0..9) and even
            if ((current <= 8'd9) && (current[0] == 1'b0)) begin
              if (write_index < 2'd4) begin
                result_array[write_index] <= current;
                write_index <= write_index + 1'b1;
                valid_count <= write_index + 1'b1;
              end
              // else: buffer full; ignore further matches
            end
            steps <= steps + 1'b1;
            current <= current + 1'b1;
            state <= RUN;
          end else begin
            state <= DONE;
            done <= 1'b1;
          end
        end

        DONE: begin
          // Remain done until a new start pulse arrives
          if (start) begin
            state <= DONE; // stay in DONE until start deasserts
          end else begin
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
