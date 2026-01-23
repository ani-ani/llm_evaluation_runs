module last_position_search (
    input clk,
    input rst_n,
    input start,
    input [7:0] target,
    input [7:0] arr [0:7],
    output reg [2:0] result,
    output reg done
);

localparam IDLE = 3'b000;
localparam COMPARE = 3'b001;
localparam UPDATE = 3'b010;
localparam DONE = 3'b100;

reg [2:0] low;
reg [2:0] high;
reg [2:0] res;
reg [2:0] state;
reg done_flag;

reg [2:0] next_high;
reg [2:0] next_low;
reg [2:0] next_res;
reg update_high;
reg update_low;
reg update_res;

always @(posedge clk) begin
  if (!rst_n) begin
    low <= 3'b000;
    high <= 3'b111;
    res <= 3'b111;
    state <= IDLE;
    done_flag <= 1'b0;
    next_high <= 3'b000;
    next_low <= 3'b000;
    next_res <= 3'b000;
    update_high <= 1'b0;
    update_low <= 1'b0;
    update_res <= 1'b0;
  end else begin
    case(state)
      IDLE: begin
        if (start) begin
          low <= 3'b000;
          high <= 3'b111;
          res <= 3'b111;
          state <= COMPARE;
          done_flag <= 1'b0;
        end else begin
          state <= IDLE;
        end
      end
      COMPARE: begin
        if (low > high) begin
          state <= DONE;
          done_flag <= 1'b1;
        end else begin
          integer mid_val;
          mid_val = (low + high) >> 1;
          if (arr[mid_val] > target) begin
            next_high = mid_val - 1;
            update_high = 1'b1;
            update_low = 1'b0;
            update_res = 1'b0;
          end else if (arr[mid_val] < target) begin
            next_low = mid_val + 1;
            update_low = 1'b1;
            update_high = 1'b0;
            update_res = 1'b0;
          end else begin
            next_low = mid_val + 1;
            update_low = 1'b1;
            update_res = 1'b1;
            next_res = mid_val;
            update_high = 1'b0;
          end
          state <= UPDATE;
        end
      end
      UPDATE: begin
        if (update_high) begin
          high <= next_high;
        end
        if (update_low) begin
          low <= next_low;
        end
        if (update_res) begin
          res <= next_res;
        end
        state <= COMPARE;
      end
      DONE: begin
        done_flag <= 1'b1;
        state <= DONE;
      end
    endcase
  end
end

assign result = res;
assign done = done_flag;
