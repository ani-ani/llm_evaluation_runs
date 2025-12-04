module max_product_subarray(
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] arr,
  output reg [15:0] max_product,
  output reg done
);

  function signed [15:0] max3;
    input signed [15:0] a, b, c;
    begin
      max3 = a;
      if (b > max3) max3 = b;
      if (c > max3) max3 = c;
    end
  endfunction

  function signed [15:0] min3;
    input signed [15:0] a, b, c;
    begin
      min3 = a;
      if (b < min3) min3 = b;
      if (c < min3) min3 = c;
    end
  endfunction

  reg [2:0] state;
  reg [3:0] index;
  reg signed [15:0] max_end;
  reg signed [15:0] min_end;
  reg signed [15:0] max_so_far;
  reg signed [15:0] new_max_end;
  reg signed [15:0] new_min_end;

  localparam IDLE = 3'b000;
  localparam INIT = 3'b001;
  localparam PROCESS = 3'b010;
  localparam OVER1 = 3'b011;
  localparam OVER2 = 3'b100;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      index <= 0;
      done <= 1'b0;
      max_end <= 0;
      min_end <= 0;
      max_so_far <= 0;
      new_max_end <= 0;
      new_min_end <= 0;
    end
    else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
          end
        end
        INIT: begin
          max_end <= $signed(arr[0]);
          min_end <= $signed(arr[0]);
          max_so_far <= $signed(arr[0]);
          state <= PROCESS;
          index <= 1;
        end
        PROCESS: begin
          if (index < 7) begin
            if (arr[index] == 8'd0) begin
              new_max_end = 16'sb1;
              new_min_end = 16'sb1;
            end
            else begin
              new_max_end = max3( $signed(max_end) * $signed(arr[index]), $signed(min_end) * $signed(arr[index]), $signed(arr[index]) );
              new_min_end = min3( $signed(max_end) * $signed(arr[index]), $signed(min_end) * $signed(arr[index]), $signed(arr[index]) );
            end
            max_end <= new_max_end;
            min_end <= new_min_end;
            if (new_max_end > max_so_far) begin
              max_so_far <= new_max_end;
            end
            index <= index + 1;
          end
          else begin
            state <= OVER1;
          end
        end
        OVER1: begin
          state <= OVER2;
        end
        OVER2: begin
          done <= 1'b1;
          state <= IDLE;
        end
        default: state <= IDLE;
      endcase
    end
  end

  assign max_product = max_so_far;

endmodule