module TopModule(
    input reg d,
    input reg ena,
    output reg q
);
    
    always @(d or ena) begin
        if (ena) begin
            q <= d;
        end
    end
    
endmodule