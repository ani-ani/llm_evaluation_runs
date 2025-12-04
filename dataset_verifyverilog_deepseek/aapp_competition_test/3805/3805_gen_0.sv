module wire_untangle (
  input clk,
  input rst_n,
  input start,
  input [15:0] data,
  output reg done,
  output reg result
);

  typedef enum logic [1:0] { IDLE, PROCESSING, DONE } state_t;

  state_t state;
  reg [15:0] stored_data;
  reg [2:0] step;
  reg [3:0] sp;
  reg [7:0] stack_reg;
  wire current_char;

  assign current_char = stored_data[step * 2];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      stored_data <= 16'b0;
      step <= 0;
      sp <= 0;
      stack_reg <= 8'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          result <= 0;
          if (start) begin
            stored_data <= data;
            step <= 0;
            sp <= 0;
            stack_reg <= 8'b0;
            state <= PROCESSING;
          end
        end

        PROCESSING: begin
          if (sp == 4'd0 || stack_reg[sp-1] != current_char) begin
            stack_reg[sp] <= current_char;
            sp <= sp + 1;
          end else begin
            sp <= sp - 1;
          end

          if (step == 3'd7) begin
            state <= DONE;
          end else begin
            step <= step + 1;
          end
        end

        DONE: begin
          done <= 1;
          result <= (sp == 0);
          if (!start) begin
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule