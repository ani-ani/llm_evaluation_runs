module TopModule(
  input  clk,
  input  reset,
  input  data,
  output reg start_shifting
);
  localparam [2:0] S_IDLE = 3'd0,
                    S_S1 = 3'd1,
                    S_S2 = 3'd2,
                    S_S3 = 3'd3,
                    S_DONE = 3'd4;
  reg [2:0] state;

  always @(posedge clk) begin
    if (reset) begin
      state <= S_IDLE;
      start_shifting <= 1'b0;
    end else begin
      case (state)
        S_IDLE: if (data) state <= S_S1; else state <= S_IDLE;
        S_S1: if (data) state <= S_S2; else state <= S_IDLE;
        S_S2: if (!data) state <= S_S3; else state <= S_IDLE;
        S_S3: if (data) state <= S_DONE; else state <= S_IDLE;
        S_DONE: state <= S_DONE;
        default: state <= S_IDLE;
      endcase
      start_shifting <= (state == S_DONE);
    end
  end
endmodule