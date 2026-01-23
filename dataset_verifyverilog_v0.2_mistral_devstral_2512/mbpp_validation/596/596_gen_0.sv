module tuple_size (
  input clk,
  input rst_n,
  input start,
  input [3:0] num_elements,
  input [7:0] element_widths [0:7],
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t state;
  reg [2:0] counter;
  reg [15:0] sum;

  // Reset logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      counter <= 0;
      sum <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            counter <= 0;
            sum <= 0;
          end
        end
        PROCESSING: begin
          if (counter < 7) begin
            counter <= counter + 1;
            sum <= sum + element_widths[counter];
          end else begin
            state <= DONE;
            result <= sum + 20;
            done <= 1;
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule