module count_first_elements (
  input clk,
  input rst_n,
  input start,
  input [7:0][1:0] data_types,
  output reg [3:0] result,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t state;
  reg [2:0] index;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      done <= 0;
      index <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            result <= 0;
            done <= 0;
            index <= 0;
          end
        end
        PROCESSING: begin
          if (data_types[index] == 2'b00) begin
            result <= result + 1;
            index <= index + 1;
            if (index == 8) begin
              state <= DONE;
            end
          end else begin
            state <= DONE;
          end
        end
        DONE: begin
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule