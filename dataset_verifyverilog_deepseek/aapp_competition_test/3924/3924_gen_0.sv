module garbage_bags(
  input clk,
  input rst_n,
  input start,
  input [15:0] k,
  input [15:0] days_data [0:15],
  input [3:0] n,
  output reg [31:0] total_bags,
  output reg done
);

  parameter [1:0] IDLE = 2'b00;
  parameter [1:0] PROCESSING = 2'b01;
  parameter [1:0] DONE = 2'b10;

  reg [1:0] state;
  reg [1:0] next_state;
  reg [15:0] current_leftover;
  reg [3:0] day_counter;
  reg [31:0] total_bags_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  always @* begin
    case (state)
      IDLE: next_state = start ? PROCESSING : IDLE;
      PROCESSING: next_state = (day_counter == n) ? DONE : PROCESSING;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      day_counter <= 4'd0;
      current_leftover <= 16'd0;
      total_bags_reg <= 32'd0;
      done <= 1'b0;
      total_bags <= 32'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            day_counter <= 4'd0;
            current_leftover <= 16'd0;
            total_bags_reg <= 32'd0;
          end
        end
        PROCESSING: begin
          if (day_counter < n) begin
            reg [16:0] current_total = days_data[day_counter] + current_leftover;
            reg [31:0] bags = current_total / k;
            reg [15:0] remainder = current_total % k;

            total_bags_reg <= total_bags_reg + bags;

            if (day_counter == (n - 4'd1)) begin
              if (remainder != 16'd0) begin
                total_bags_reg <= total_bags_reg + bags + 32'd1;
              end
              current_leftover <= 16'd0;
            end else if (current_total < k && remainder != 16'd0) begin
              total_bags_reg <= total_bags_reg + bags + 32'd1;
              current_leftover <= 16'd0;
            end else begin
              current_leftover <= remainder;
            end

            day_counter <= day_counter + 4'd1;
          end
        end
        DONE: begin
          total_bags <= total_bags_reg;
          done <= 1'b1;
        end
      endcase
    end
  end

endmodule