module TopModule (
  input clk,
  input load,
  input [511:0] data,
  output reg [511:0] q
);
  reg [511:0] current_state;
  wire [511:0] next_state;

  always @(posedge clk) begin
    if (load)
      current_state <= data;
    else
      current_state <= next_state;
  end

  assign q = current_state;

  genvar i;
  generate
    for (i = 0; i < 512; i = i + 1) begin : rule110_gen
      wire left_neighbor  = (i == 0) ? 1'b0 : current_state[i-1];
      wire right_neighbor = (i == 511) ? 1'b0 : current_state[i+1];
      
      always_comb begin
        case ({left_neighbor, current_state[i], right_neighbor})
          3'b111: next_state[i] = 1'b0;
          3'b110: next_state[i] = 1'b1;
          3'b101: next_state[i] = 1'b1;
          3'b100: next_state[i] = 1'b0;
          3'b011: next_state[i] = 1'b1;
          3'b010: next_state[i] = 1'b1;
          3'b001: next_state[i] = 1'b1;
          3'b000: next_state[i] = 1'b0;
          default: next_state[i] = 1'b0;
        endcase
      end
    end
  endgenerate
endmodule