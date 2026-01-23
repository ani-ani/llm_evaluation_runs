module can_arrange (
  input clk,
  input rst_n,
  input start,
  input [3:0] length,
  input [15:0] arr [0:15],
  output reg [3:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t state = IDLE;
  reg [3:0] index = 0;
  reg [3:0] max_index = 15; // Default to -1 (0xF)
  reg [3:0] counter = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      index <= 0;
      max_index <= 15;
      counter <= 0;
      result <= 15;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            index <= 1;
            max_index <= 15;
            counter <= 0;
            done <= 0;
          end
        end
        PROCESSING: begin
          if (counter < length - 1) begin
            if (arr[index] < arr[index - 1]) begin
              max_index <= index;
            end
            index <= index + 1;
            counter <= counter + 1;
          end else begin
            state <= DONE;
            result <= max_index;
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