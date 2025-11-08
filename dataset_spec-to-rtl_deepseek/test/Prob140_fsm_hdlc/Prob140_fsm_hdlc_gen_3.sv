module TopModule(
  input clk,
  input reset,
  input in,
  output reg disc,
  output reg flag,
  output reg err
);

  typedef enum reg [3:0] {
    IDLE = 4'd0,
    S1 = 4'd1,
    S2 = 4'd2,
    S3 = 4'd3,
    S4 = 4'd4,
    S5 = 4'd5,
    S6 = 4'd6,
    DISC_STATE = 4'd7,
    FLAG_STATE = 4'd8,
    ERR_STATE = 4'd9
  } state_t;

  state_t current_state, next_state;

  always @(posedge clk) begin
    if (reset) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  always @(*) begin
    next_state = current_state;
    disc = 1'b0;
    flag = 1'b0;
    err = 1'b0;

    case (current_state)
      IDLE: begin
        if (in) begin
          next_state = S1;
        end
      end
      S1: begin
        if (in) begin
          next_state = S2;
        end else begin
          next_state = IDLE;
        end
      end
      S2: begin
        if (in) begin
          next_state = S3;
        end else begin
          next_state = IDLE;
        end
      end
      S3: begin
        if (in) begin
          next_state = S4;
        end else begin
          next_state = IDLE;
        end
      end
      S4: begin
        if (in) begin
          next_state = S5;
        end else begin
          next_state = IDLE;
        end
      end
      S5: begin
        if (!in) begin
          next_state = DISC_STATE;
        end else begin
          next_state = FLAG_STATE;
        end
      end
      S6: begin
        if (!in) begin
          next_state = IDLE;
        end else begin
          next_state = ERR_STATE;
        end
      end
      DISC_STATE: begin
        disc = 1'b1;
        if (in) begin
          next_state = S1;
        end else begin
          next_state = IDLE;
        end
      end
      FLAG_STATE: begin
        flag = 1'b1;
        if (in) begin
          next_state = S1;
        end else begin
          next_state = IDLE;
        end
      end
      ERR_STATE: begin
        err = 1'b1;
        if (!in) begin
          next_state = IDLE;
        end // else stay in ERR_STATE
      end
    endcase
  end

endmodule