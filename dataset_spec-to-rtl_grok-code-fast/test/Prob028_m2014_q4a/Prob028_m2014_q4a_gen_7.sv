module TopModule(
    input d,
    input ena,
    output reg q
);

always @(*) begin
    if (ena) begin
        q <= d;
    end
    // else q holds its value (latch behavior)
end

endmodule