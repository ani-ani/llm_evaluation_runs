module snake_exhibition (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0] s,
  output reg [3:0] result,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [2:0] room_index;
  reg [3:0] count;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      room_index <= 0;
      count <= 0;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
      if (current_state == PROCESSING) begin
        if (room_index == n - 1) begin
          room_index <= 0;
        end else begin
          room_index <= room_index + 1;
        end
      end else begin
        room_index <= 0;
      end
      if (current_state == PROCESSING && room_index == 0) begin
        count <= 0;
      end else if (current_state == PROCESSING) begin
        count <= count + (check_room(room_index, n, s) ? 1 : 0);
      end
      if (current_state == DONE) begin
        result <= count;
      end
    end
  end

  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = PROCESSING;
        else next_state = IDLE;
      end
      PROCESSING: begin
        if (room_index == n - 1) next_state = DONE;
        else next_state = PROCESSING;
      end
      DONE: begin
        if (start) next_state = PROCESSING;
        else next_state = IDLE;
      end
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
    end else begin
      done <= (current_state == DONE);
    end
  end

  function automatic bit check_room(input [2:0] i, input [2:0] n, input [7:0] s);
    bit returnable;
    reg [7:0] s_extended;
    s_extended = {s, s[7:0]};

    if (s_extended[i] == 0) begin
      returnable = 1;
    end else if (s_extended[i-1] == 0) begin
      returnable = 1;
    end else if (s_extended[i] == 1 && s_extended[i-1] == 1) begin
      returnable = 1;
    end else if (s_extended[i] == 2 && s_extended[i-1] == 2) begin
      returnable = 1;
    end else begin
      returnable = 0;
    end
    return returnable;
  endfunction

endmodule