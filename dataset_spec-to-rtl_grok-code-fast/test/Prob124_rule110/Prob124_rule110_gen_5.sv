module TopModule(
  input clk,
  input load,
  input [511:0] data,
  output reg [511:0] q
);

wire [511:0] next_q;

generate
genvar i;
for (i=0; i<512; i++) begin : gen_rule110
  wire left = (i == 0) ? 1'b0 : q[i-1];
  wire right = (i == 511) ? 1'b0 : q[i+1];
  assign next_q[i] = ({left, q[i], right} == 3'b111) ? 1'b0 :
                     ({left, q[i], right} == 3'b110) ? 1'b1 :
                     ({left, q[i], right} == 3'b101) ? 1'b1 :
                     ({left, q[i], right} == 3'b100) ? 1'b0 :
                     ({left, q[i], right} == 3'b011) ? 1'b1 :
                     ({left, q[i], right} == 3'b010) ? 1'b1 :
                     ({left, q[i], right} == 3'b001) ? 1'b1 :
                     ({left, q[i], right} == 3'b000) ? 1'b0 :
                     1'b0; // default
end
endgenerate

always @(posedge clk) begin
  if (load) begin
    q <= data;
  end else begin
    q <= next_q;
  end
end

endmodule