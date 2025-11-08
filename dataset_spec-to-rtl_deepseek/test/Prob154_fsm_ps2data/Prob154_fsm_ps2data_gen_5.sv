module TopModule(input clk, input reset, input [7:0] in, output logic [23:0] out_bytes, output logic done);
  typedef enum logic [1:0] {IDLE, BYTE2, BYTE3, DONE} State;
  State state;
  logic [7:0] byte1, byte2, byte3;

  always_ff @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
      byte1 <= '0;
      byte2 <= '0;
      byte3 <= '0;
    end else begin
      case (state)
        IDLE: if (in[3]) begin
          state <= BYTE2;
          byte1 <= in;
        end
        BYTE2: begin
          state <= BYTE3;
          byte2 <= in;
        end
        BYTE3: begin
          state <= DONE;
          byte3 <= in;
        end
        DONE: state <= IDLE;
        default: state <= IDLE;
      endcase
    end
  end

  assign done = (state == DONE);
  assign out_bytes = {byte1, byte2, byte3};
endmodule