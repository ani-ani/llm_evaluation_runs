module max_executives (
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  input [15:0] bananas [0:7],
  output reg [3:0] k,
  output reg done
);

// States
localparam IDLE  = 3'd0;
localparam INIT  = 3'd1;
localparam ACCUM = 3'd2;
localparam COMPARE = 3'd3;
localparam DONE  = 3'd4;

reg [2:0] state, next_state;
reg [19:0] current_sum, last_sum;
reg [3:0] index;
reg [3:0] valid_segments;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    current_sum <= 0;
    last_sum <= 0;
    index <= 0;
    valid_segments <= 0;
    done <= 0;
    k <= 0;
  end
  else begin
    state <= next_state;
    done <= 0;
    case (state)
      INIT: begin
        current_sum <= 0;
        last_sum <= 0;
        index <= 0;
        valid_segments <= 0;
      end
      ACCUM: begin
        current_sum <= current_sum + bananas[index];
      end
      COMPARE: begin
        if (current_sum >= last_sum) begin
          valid_segments <= valid_segments + 4'd1;
          last_sum <= current_sum;
          current_sum <= 0;
        end
        index <= index + 4'd1;
      end
      DONE: begin
        k <= valid_segments;
        done <= 1;
      end
      default: ;
    endcase
  end
end

always @(*) begin
  case (state)
    IDLE: next_state = start ? INIT : IDLE;
    INIT: next_state = ACCUM;
    ACCUM: next_state = COMPARE;
    COMPARE: next_state = (index == (N - 1)) ? DONE : ACCUM;
    DONE: next_state = IDLE;
    default: next_state = IDLE;
  endcase
end

endmodule