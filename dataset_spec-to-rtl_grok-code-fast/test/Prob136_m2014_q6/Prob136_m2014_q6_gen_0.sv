module TopModule(
    input clk,
    input reset,
    input w,
    output reg z
);
    parameter A = 0;
    parameter B = 1;
    parameter C = 2;
    parameter D = 3;
    parameter E = 4;
    parameter F = 5;
    
    reg [2:0] state, next_state;
    
    always @(posedge clk or posedge reset) begin
        if (reset) state <= A;
        else state <= next_state;
    end
    
    always @(*) begin
        case (state)
            A: next_state = (w == 0) ? B : A;
            B: next_state = (w == 0) ? C : D;
            C: next_state = (w == 0) ? E : D;
            D: next_state = (w == 0) ? F : A;
            E: next_state = (w == 0) ? E : D;
            F: next_state = (w == 0) ? C : D;
        endcase
    end
    
    always @(*) begin
        case (state)
            E: z = 1;
            F: z = 1;
            default: z = 0;
        endcase
    end
endmodule