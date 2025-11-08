module TopModule(
    input clock,
    input a,
    output reg p,
    output reg q
);
    assign p = clock && a;
    always_ff @(negedge clock) begin
        q <= p;
    end
endmodule