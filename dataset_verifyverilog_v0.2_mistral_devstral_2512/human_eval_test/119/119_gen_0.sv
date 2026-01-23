module match_parens (
  input clk,
  input rst_n,
  input start,
  input [7:0] str1 [0:7],
  input [7:0] str2 [0:7],
  output reg result,
  output reg done
);

  parameter MAX_LEN = 8;
  parameter IDLE = 3'b000;
  parameter CHECK_S1_S2 = 3'b001;
  parameter CHECK_S2_S1 = 3'b010;
  parameter COMPUTE_RESULT = 3'b011;
  parameter DONE = 3'b100;

  reg [2:0] state = IDLE;
  reg [3:0] counter = 0;
  reg [3:0] depth_s1_s2 = 0;
  reg [3:0] depth_s2_s1 = 0;
  reg [3:0] index = 0;
  reg valid_s1_s2 = 0;
  reg valid_s2_s1 = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      counter <= 0;
      depth_s1_s2 <= 0;
      depth_s2_s1 <= 0;
      index <= 0;
      valid_s1_s2 <= 0;
      valid_s2_s1 <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CHECK_S1_S2;
            counter <= 0;
            depth_s1_s2 <= 0;
            depth_s2_s1 <= 0;
            index <= 0;
            valid_s1_s2 <= 0;
            valid_s2_s1 <= 0;
            result <= 0;
            done <= 0;
          end
        end
        CHECK_S1_S2: begin
          if (counter < 2 * MAX_LEN) begin
            if (counter < MAX_LEN) begin
              if (str1[index] == 8'b00101000) begin // '('
                depth_s1_s2 <= depth_s1_s2 + 1;
              end else if (str1[index] == 8'b00101001) begin // ')'
                if (depth_s1_s2 > 0) begin
                  depth_s1_s2 <= depth_s1_s2 - 1;
                end else begin
                  valid_s1_s2 <= 0;
                end
              end
            end else begin
              if (str2[index - MAX_LEN] == 8'b00101000) begin // '('
                depth_s1_s2 <= depth_s1_s2 + 1;
              end else if (str2[index - MAX_LEN] == 8'b00101001) begin // ')'
                if (depth_s1_s2 > 0) begin
                  depth_s1_s2 <= depth_s1_s2 - 1;
                end else begin
                  valid_s1_s2 <= 0;
                end
              end
            end
            counter <= counter + 1;
            index <= index + 1;
            if (counter == 2 * MAX_LEN - 1) begin
              if (depth_s1_s2 == 0) begin
                valid_s1_s2 <= 1;
              end
            end
          end else begin
            state <= CHECK_S2_S1;
            counter <= 0;
            depth_s2_s1 <= 0;
            index <= 0;
          end
        end
        CHECK_S2_S1: begin
          if (counter < 2 * MAX_LEN) begin
            if (counter < MAX_LEN) begin
              if (str2[index] == 8'b00101000) begin // '('
                depth_s2_s1 <= depth_s2_s1 + 1;
              end else if (str2[index] == 8'b00101001) begin // ')'
                if (depth_s2_s1 > 0) begin
                  depth_s2_s1 <= depth_s2_s1 - 1;
                end else begin
                  valid_s2_s1 <= 0;
                end
              end
            end else begin
              if (str1[index - MAX_LEN] == 8'b00101000) begin // '('
                depth_s2_s1 <= depth_s2_s1 + 1;
              end else if (str1[index - MAX_LEN] == 8'b00101001) begin // ')'
                if (depth_s2_s1 > 0) begin
                  depth_s2_s1 <= depth_s2_s1 - 1;
                end else begin
                  valid_s2_s1 <= 0;
                end
              end
            end
            counter <= counter + 1;
            index <= index + 1;
            if (counter == 2 * MAX_LEN - 1) begin
              if (depth_s2_s1 == 0) begin
                valid_s2_s1 <= 1;
              end
            end
          end else begin
            state <= COMPUTE_RESULT;
          end
        end
        COMPUTE_RESULT: begin
          result <= valid_s1_s2 | valid_s2_s1;
          state <= DONE;
        end
        DONE: begin
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule