module TopModule (
    input clk,
    input reset,
    input in,
    output reg out
);
    reg [1:0] state;
    parameter A = 2'b00;
    parameter B = 2'b01;
    parameter C = 2'b10;
    parameter D = 2'b11;
    
    always @(posedge clk) begin
        if (reset) begin
            state <= A;
        end else begin
            case (state)
                A: state <= in ? B : A;
                B: state <= in ? B : C;
                C: state <= in ? D : A;
                D: state <= in ? B : C;
                default: state <= A;
            endcase
        end
    end
    
    always @* begin
        case (state)
            A, B, C: out = 0;
            D: out = 1;
            default: out = 0;
        endcase
    end
endmodule