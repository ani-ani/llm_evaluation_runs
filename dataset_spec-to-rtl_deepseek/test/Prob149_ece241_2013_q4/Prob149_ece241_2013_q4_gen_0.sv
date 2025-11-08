module TopModule(
  input clk,
  input reset,
  input [2:0] s,
  output fr2,
  output fr1,
  output fr0,
  output dfr
);
  reg [1:0] current_state;
  reg [1:0] previous_state;
  wire [1:0] next_state = s[2] ? 2'b11 : 
                       s[1] ? 2'b10 :
                       s[0] ? 2'b01 : 
                              2'b00;

  always_ff @(posedge clk) begin
    if (reset) begin
      current_state <= 2'b00;
      previous_state <= 2'b11;
    end else begin
      previous_state <= current_state;
      current_state <= next_state;
    end
  end

  assign fr0 = (current_state != 2'b11);
  assign fr1 = (current_state == 2'b01 || current_state == 2'b00);
  assign fr2 = (current_state == 2'b00);
  assign dfr = ($signed(previous_state) < $signed(current_state));
endmodule