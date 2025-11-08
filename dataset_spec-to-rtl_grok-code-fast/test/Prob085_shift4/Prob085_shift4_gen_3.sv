module TopModule (
    input reg clk,
    input reg areset,
    input reg load,
    input reg ena,
    input reg [3:0] data,
    output reg [3:0] q
);

always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
        q <= 4'b0000;
    end else if (load) begin
        q <= data;
    end else if (ena) begin
        q <= {1'b0, q[3:1]};
    end
end
endmodule