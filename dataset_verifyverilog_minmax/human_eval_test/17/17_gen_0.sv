module music_parser (
  input clk,
  input rst_n,
  input start,
  input [5:0] length,
  input [255:0] music_string,
  output reg [2:0] beat,
  output reg beat_valid,
  output reg done
);

localparam IDLE = 2'd0;
localparam SKIP = 2'd1;
localparam TOKEN = 2'd2;

reg [1:0] state, next_state;
reg [5:0] index, next_index;
reg [255:0] captured_string;
reg [5:0] captured_length;
reg next_done;
reg [2:0] next_beat;
reg next_beat_valid;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    index <= 0;
    done <= 0;
    beat <= 0;
    beat_valid <= 0;
    captured_string <= 0;
    captured_length <= 0;
  end
  else begin
    state <= next_state;
    index <= next_index;
    done <= next_done;
    beat <= next_beat;
    beat_valid <= next_beat_valid;

    if (state == IDLE && start) begin
      captured_string <= music_string;
      captured_length <= length;
    end
  end
end

always @(*) begin
  next_state = state;
  next_index = index;
  next_done = done;
  next_beat = beat;
  next_beat_valid = 1'b0;

  case (state)
    IDLE: begin
      next_done = 1'b0;
      if (start) begin
        next_state = SKIP;
        next_index = 0;
      end
    end

    SKIP: begin
      next_done = 1'b0;
      if (index >= captured_length) begin
        next_state = IDLE;
        next_index = 0;
        next_done = 1'b1;
      end
      else if (captured_string[index*8 +: 8] == 8'h20) begin
        next_index = index + 1;
      end
      else begin
        next_state = TOKEN;
      end
    end

    TOKEN: begin
      if (index >= captured_length) begin
        if (captured_string[index*8 +: 8] == 8'h6F) begin
          next_beat = 3'b100;
          next_beat_valid = 1'b1;
          next_index = index + 1;
          next_state = SKIP;
        end
        else begin
          next_beat = 3'b0;
          next_beat_valid = 1'b0;
          next_state = IDLE;
          next_index = 0;
          next_done = 1'b1;
        end
      end
      else begin
        if (captured_string[index*8 +: 8] == 8'h6F) begin
          if (index+1 < captured_length && captured_string[(index+1)*8 +: 8] == 8'h7C) begin
            next_beat = 3'b010;
            next_beat_valid = 1'b1;
            next_index = index + 2;
            next_state = SKIP;
          end
          else begin
            next_beat = 3'b100;
            next_beat_valid = 1'b1;
            next_index = index + 1;
            next_state = SKIP;
          end
        end
        else if (captured_string[index*8 +: 8] == 8'h2E) begin
          if (index+1 < captured_length && captured_string[(index+1)*8 +: 8] == 8'h7C) begin
            next_beat = 3'b001;
            next_beat_valid = 1'b1;
            next_index = index + 2;
            next_state = SKIP;
          end
          else begin
            next_beat = 3'b0;
            next_beat_valid = 1'b0;
            next_state = IDLE;
            next_index = 0;
            next_done = 1'b1;
          end
        end
        else begin
          next_beat = 3'b0;
          next_beat_valid = 1'b0;
          next_state = IDLE;
          next_index = 0;
          next_done = 1'b1;
        end
      end
    end
  endcase
end

endmodule