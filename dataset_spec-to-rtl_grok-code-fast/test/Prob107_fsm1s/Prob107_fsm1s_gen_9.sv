module TopModule (input clk, input reset, input in, output out);

logic current_state;
parameter A = 1'b0;
parameter B = 1'b1;

assign out = current_state;

always @(posedge clk) begin
    if (reset) begin
        current_state <= B;
    end else begin
        case (current_state)
            A: if (in == 1) current_state <= A; else current_state <= B;
            B: if (in == 1) current_state <= B; else current_state <= A;
        endcase
    end
end

endmodule