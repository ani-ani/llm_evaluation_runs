module TopModule (
    input clk,
    input reset,
    output logic [4:0] q
);
    always_ff @(posedge clk) begin
        if (reset) begin
            q <= 5'b00001;
        end else begin
            logic feedback = q[4] ^ q[2] ^ q[0];
            q <= {feedback, q[4:1]};
        end
    end
endmodule