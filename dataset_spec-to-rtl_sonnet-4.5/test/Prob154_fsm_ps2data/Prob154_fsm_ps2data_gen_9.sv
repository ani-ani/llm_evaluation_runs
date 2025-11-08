module TopModule(
  input clk,
  input reset,
  input [7:0] in,
  output reg [23:0] out_bytes,
  output reg done
);

  // State encoding
  typedef enum reg [1:0] {
    IDLE = 2'b00,
    BYTE1 = 2'b01,
    BYTE2 = 2'b10,
    BYTE3 = 2'b11
  } state_t;

  state_t current_state, next_state;

  // Registers to store the three bytes
  reg [7:0] byte1, byte2, byte3;

  // State transition logic
  always @(posedge clk) begin
    if (reset) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    case (current_state)
      IDLE: begin
        if (in[3] == 1'b1)
          next_state = BYTE1;
        else
          next_state = IDLE;
      end
      BYTE1: begin
        next_state = BYTE2;
      end
      BYTE2: begin
        next_state = BYTE3;
      end
      BYTE3: begin
        if (in[3] == 1'b1)
          next_state = BYTE1;
        else
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath: Store bytes
  always @(posedge clk) begin
    if (reset) begin
      byte1 <= 8'b0;
      byte2 <= 8'b0;
      byte3 <= 8'b0;
    end else begin
      case (current_state)
        IDLE: begin
          if (in[3] == 1'b1) begin
            byte1 <= in;
          end
        end
        BYTE1: begin
          byte2 <= in;
        end
        BYTE2: begin
          byte3 <= in;
        end
        BYTE3: begin
          if (in[3] == 1'b1) begin
            byte1 <= in;
          end
        end
      endcase
    end
  end

  // Output logic
  always @(posedge clk) begin
    if (reset) begin
      done <= 1'b0;
      out_bytes <= 24'b0;
    end else begin
      if (current_state == BYTE2) begin
        done <= 1'b1;
        out_bytes <= {byte1, byte2, in};
      end else begin
        done <= 1'b0;
        out_bytes <= 24'bx;
      end
    end
  end

endmodule