module bracket_nested_check(
  input clk,
  input rst_n,
  input start,
  input [3:0] length,
  input [15:0] data,
  output reg result,
  output reg done
);

  typedef enum logic {IDLE, PROCESSING} state_t;
  state_t state;

  reg [15:0] shift_reg;
  reg [3:0] depth;
  reg nested_flag;
  reg [3:0] count;

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      shift_reg <= 0;
      depth <= 0;
      nested_flag <= 0;
      count <= 0;
    end else begin
      done <= 0;
      case (state)
        IDLE: begin
          if (start) begin
            if (length == 4'b0) begin
              result <= 0;
              done <= 1'b1;
            end else begin
              state <= PROCESSING;
              shift_reg <= data;
              depth <= 0;
              nested_flag <= 0;
              count <= 0;
            end
          end
        end

        PROCESSING: begin
          if (shift_reg[0] == 1'b0) begin
            if (depth != 4'b1111) depth <= depth + 1;
          end else begin
            if (depth >= 4'b0010) nested_flag <= 1'b1;
            if (depth != 4'b0000) depth <= depth - 1;
          end

          shift_reg <= shift_reg >> 1;
          count <= count + 1;

          if (count == length - 1) begin
            result <= nested_flag;
            done <= 1'b1;
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule