module zero_ratio (
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg signed [7:0] array [0:7],
  output reg [15:0] ratio,
  output reg done,
  output reg error
);

reg [3:0] state;
reg [3:0] element_index;
reg [3:0] zero_count;
reg [3:0] non_zero_count;

localparam IDLE = 4'd0, COUNT = 4'd1, DIVIDE = 4'd2, DONE = 4'd3;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    element_index <= 0;
    zero_count <= 0;
    non_zero_count <= 0;
    ratio <= 0;
    done <= 0;
    error <= 0;
  end
  else begin
    case (state)
      IDLE: begin
        if (start) begin
          state <= COUNT;
          element_index <= 0;
          zero_count <= 0;
          non_zero_count <= 0;
          done <= 0;
          error <= 0;
        end
      end

      COUNT: begin
        // Process the current element
        if (array[element_index] == 0) begin
          zero_count <= zero_count + 1;
        end
        else begin
          non_zero_count <= non_zero_count + 1;
        end

        // Increment the index
        if (element_index == 7) begin
          state <= DIVIDE;
        end
        else begin
          element_index <= element_index + 1;
        end
      end

      DIVIDE: begin
        if (non_zero_count == 0) begin
          error <= 1;
          done <= 1;
          ratio <= 0;
        end
        else begin
          case (non_zero_count)
            4'd1: ratio <= (zero_count * 256);
            4'd2: ratio <= (zero_count * 256) / 2;
            4'd3: ratio <= (zero_count * 256) / 3;
            4'd4: ratio <= (zero_count * 256) / 4;
            4'd5: ratio <= (zero_count * 256) / 5;
            4'd6: ratio <= (zero_count * 256) / 6;
            4'd7: ratio <= (zero_count * 256) / 7;
            4'd8: ratio <= (zero_count * 256) / 8;
            default: ratio <= 0;
          endcase
          done <= 1;
          error <= 0;
        end
        state <= DONE;
      end

      DONE: begin
        if (start) begin
          state <= COUNT;
          element_index <= 0;
          zero_count <= 0;
          non_zero_count <= 0;
          done <= 0;
          error <= 0;
        end
      end

      default: begin
        state <= IDLE;
      end
    endcase
  end
end

endmodule