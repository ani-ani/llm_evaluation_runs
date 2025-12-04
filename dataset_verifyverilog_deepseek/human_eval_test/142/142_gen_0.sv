module sum_squares(
  input clk,
  input rst_n,
  input start,
  input [3:0] length,
  input [15:0] lst_0,
  input [15:0] lst_1,
  input [15:0] lst_2,
  input [15:0] lst_3,
  input [15:0] lst_4,
  input [15:0] lst_5,
  input [15:0] lst_6,
  input [15:0] lst_7,
  output reg signed [31:0] sum,
  output reg done
);

  parameter IDLE = 2'b00;
  parameter PROCESSING = 2'b01;
  parameter POST = 2'b10;
  
  reg [1:0] state;
  reg [3:0] index;
  reg signed [31:0] internal_sum;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      sum <= 32'sd0;
      internal_sum <= 32'sd0;
      index <= 4'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          internal_sum <= 32'sd0;
          index <= 4'd0;
          if (start) state <= PROCESSING;
        end
        
        PROCESSING: begin
          if (index < length) begin
            case (index)
              4'd0: begin
                if (index % 3 == 0)
                  internal_sum <= internal_sum + lst_0 * lst_0;
                else if (index % 4 == 0)
                  internal_sum <= internal_sum + lst_0 * lst_0 * lst_0;
                else
                  internal_sum <= internal_sum + lst_0;
              end
              4'd1: begin
                if (index % 3 == 0)
                  internal_sum <= internal_sum + lst_1 * lst_1;
                else if (index % 4 == 0)
                  internal_sum <= internal_sum + lst_1 * lst_1 * lst_1;
                else
                  internal_sum <= internal_sum + lst_1;
              end
              4'd2: begin
                if (index % 3 == 0)
                  internal_sum <= internal_sum + lst_2 * lst_2;
                else if (index % 4 == 0)
                  internal_sum <= internal_sum + lst_2 * lst_2 * lst_2;
                else
                  internal_sum <= internal_sum + lst_2;
              end
              4'd3: begin
                if (index % 3 == 0)
                  internal_sum <= internal_sum + lst_3 * lst_3;
                else if (index % 4 == 0)
                  internal_sum <= internal_sum + lst_3 * lst_3 * lst_3;
                else
                  internal_sum <= internal_sum + lst_3;
              end
              4'd4: begin
                if (index % 3 == 0)
                  internal_sum <= internal_sum + lst_4 * lst_4;
                else if (index % 4 == 0)
                  internal_sum <= internal_sum + lst_4 * lst_4 * lst_4;
                else
                  internal_sum <= internal_sum + lst_4;
              end
              4'd5: begin
                if (index % 3 == 0)
                  internal_sum <= internal_sum + lst_5 * lst_5;
                else if (index % 4 == 0)
                  internal_sum <= internal_sum + lst_5 * lst_5 * lst_5;
                else
                  internal_sum <= internal_sum + lst_5;
              end
              4'd6: begin
                if (index % 3 == 0)
                  internal_sum <= internal_sum + lst_6 * lst_6;
                else if (index % 4 == 0)
                  internal_sum <= internal_sum + lst_6 * lst_6 * lst_6;
                else
                  internal_sum <= internal_sum + lst_6;
              end
              4'd7: begin
                if (index % 3 == 0)
                  internal_sum <= internal_sum + lst_7 * lst_7;
                else if (index % 4 == 0)
                  internal_sum <= internal_sum + lst_7 * lst_7 * lst_7;
                else
                  internal_sum <= internal_sum + lst_7;
              end
            endcase
            index <= index + 1;
          end else begin
            state <= POST;
          end
        end
        
        POST: begin
          done <= 1'b1;
          sum <= internal_sum;
          if (start) begin
            state <= IDLE;
            done <= 1'b0;
          end else begin
            state <= POST;
          end
        end
      endcase
    end
  end

endmodule