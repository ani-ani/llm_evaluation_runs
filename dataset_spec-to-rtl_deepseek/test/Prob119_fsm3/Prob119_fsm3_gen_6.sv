module TopModule(input clk, input areset, input in, output out);
  localparam A = 2'd0;
  localparam B = 2'd1;
  localparam C = 2'd2;
  localparam D = 2'd3;
  reg [1:0] current_state;
  always @(posedge clk or posedge areset) begin
    if (areset) current_state <= A;
    else begin
      case (current_state)
        A: current_state <= in ? B : A;
        B: current_state <= in ? B : C;
        C: current_state <= in ? D : A;
        D: current_state <= in ? B : C;
      endcase
    end
  end
  assign out = (current_state == D);
endmodule