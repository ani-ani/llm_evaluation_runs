module integer_filter (
  input clk,
  input rst_n,
  input start,
  input [7:0][9:0] values,
  output reg [7:0][7:0] result,
  output reg [7:0] valid_mask,
  output reg done
);

  typedef enum logic [1:0] {IDLE, PROCESSING, DONE} state_t;
  state_t state;
  reg [7:0][9:0] captured_values;
  reg [3:0] count;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 8'b0;
      valid_mask <= 8'b0;
      done <= 1'b0;
      captured_values <= 80'b0;
      count <= 4'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            captured_values <= values;
            state <= PROCESSING;
            count <= 4'b0;
          end
        end
        PROCESSING: begin
          // Process current element based on type
          if (captured_values[count][9:8] == 2'b01) begin
            result[count] <= captured_values[count][7:0];
            valid_mask[count] <= 1'b1;
          end else begin
            result[count] <= 8'b0;
            valid_mask[count] <= 1'b0;
          end
          
          count <= count + 1;
          if (count == 4'd7) begin
            state <= DONE;
            done <= 1'b1;
          end
        end
        DONE: begin
          if (start) begin
            captured_values <= values;
            state <= PROCESSING;
            count <= 4'b0;
            done <= 1'b0;
          end
        end
      endcase
    end
  end

endmodule