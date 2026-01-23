module max_f_value (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0][15:0] a,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    LOAD,
    PROCESS,
    CALC,
    DONE
  } state_t;

  state_t state;
  reg [2:0] i;
  reg [15:0] diff;
  reg [31:0] seq1_current, seq1_max;
  reg [31:0] seq2_current, seq2_max;
  reg [31:0] max_result;
  reg [3:0] counter;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 0;
      diff <= 0;
      seq1_current <= 0;
      seq1_max <= 0;
      seq2_current <= 0;
      seq2_max <= 0;
      max_result <= 0;
      counter <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD;
            counter <= 0;
          end
        end

        LOAD: begin
          if (n >= 2 && n <= 8) begin
            state <= PROCESS;
            i <= 0;
            seq1_current <= 0;
            seq1_max <= 0;
            seq2_current <= 0;
            seq2_max <= 0;
          end else begin
            state <= IDLE;
          end
        end

        PROCESS: begin
          if (i < n - 1) begin
            // Compute absolute difference
            diff <= (a[i] > a[i+1]) ? (a[i] - a[i+1]) : (a[i+1] - a[i]);

            // Compute sequences with alternating signs
            if (i % 2 == 0) begin
              seq1_current <= seq1_current + diff;
              seq2_current <= seq2_current - diff;
            end else begin
              seq1_current <= seq1_current - diff;
              seq2_current <= seq2_current + diff;
            end

            // Update max values
            if (seq1_current > seq1_max) begin
              seq1_max <= seq1_current;
            end
            if (seq2_current > seq2_max) begin
              seq2_max <= seq2_current;
            end

            // Move to next element
            i <= i + 1;
          end else begin
            state <= CALC;
          end
        end

        CALC: begin
          // Compare final max values from both sequences
          max_result <= (seq1_max > seq2_max) ? seq1_max : seq2_max;
          state <= DONE;
        end

        DONE: begin
          if (counter < 20) begin
            counter <= counter + 1;
          end else begin
            result <= max_result;
            done <= 1;
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule