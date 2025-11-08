module TopModule(
    input  clk,
    input  reset,
    input  w,
    output z
);

    parameter A = 3'b000;
    parameter B = 3'b001;
    parameter C = 3'b010;
    parameter D = 3'b011;
    parameter E = 3'b100;
    parameter F = 3'b101;

    reg [2:0] state;

    always @(posedge clk) begin
        if (reset) begin
            state <= A;
        end else begin
            case (state)
                A: state <= (w == 0) ? B : A;
                B: state <= (w == 0) ? C : D;
                C: state <= (w == 0) ? E : D;
                D: state <= (w == 0) ? F : A;
                E: state <= (w == 0) ? E : D;
                F: state <= (w == 0) ? C : D;
            endcase
        end
    end

    assign z = (state == E) || (state == F);

endmodule