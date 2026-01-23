module insert_element (
  input clk,
  input rst_n,
  input start,
  input [7:0] element,
  input [7:0] list_data [0:7],
  input [2:0] list_len,
  output reg [7:0] result [0:15],
  output reg [3:0] result_len,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t state = IDLE;
  reg [3:0] counter = 0;
  reg [3:0] write_index = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      counter <= 0;
      write_index <= 0;
      done <= 0;
      result_len <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            counter <= 0;
            write_index <= 0;
            done <= 0;
          end
        end
        PROCESSING: begin
          if (counter < list_len) begin
            if (write_index[0] == 0) begin
              result[write_index] <= element;
            end else begin
              result[write_index] <= list_data[counter];
              counter <= counter + 1;
            end
            write_index <= write_index + 1;
            if (write_index == 2 * list_len) begin
              state <= DONE;
              result_len <= 2 * list_len;
              done <= 1;
            end
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