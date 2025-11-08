module TopModule(input clk, input areset, input x, output logic z);
  typedef enum logic { A, B } state_t;
  state_t state;

  always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
      state <= A;
      z <= 1'b0;
    end else begin
      case (state)
        A: begin
            if (x) state <= B;
            z <= x;
          end
        B: begin
            z <= ~x;
          end
      endcase
    end
  end
endmodule