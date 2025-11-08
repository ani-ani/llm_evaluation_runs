module TopModule(
    input clk,
    input resetn,
    input x,
    input y,
    output f,
    output g
);
    reg [3:0] current_state, next_state;
    parameter RESET = 4'd0,
              SETF = 4'd1,
              WX0 = 4'd2,
              WX1 = 4'd3,
              WX2 = 4'd4,
              SETG = 4'd5,
              YCHK1 = 4'd6,
              YCHK2 = 4'd7,
              PERM1 = 4'd8,
              PERM0 = 4'd9;
    always @(posedge clk) begin
        current_state <= next_state;
    end
    always @* begin
        if (!resetn)
            next_state = RESET;
        else
            case (current_state)
                RESET: next_state = SETF;
                SETF: next_state = WX0;
                WX0: if (x) next_state = WX1; else next_state = WX0;
                WX1: if (!x) next_state = WX2; else next_state = WX0;
                WX2: if (x) next_state = SETG; else next_state = WX0;
                SETG: next_state = YCHK1;
                YCHK1: if (y) next_state = PERM1; else next_state = YCHK2;
                YCHK2: if (y) next_state = PERM1; else next_state = PERM0;
                PERM1: next_state = PERM1;
                PERM0: next_state = PERM0;
                default: next_state = RESET;
            endcase
    end
    assign f = (current_state == SETF);
    assign g = ((current_state == SETG) || (current_state == YCHK1) || (current_state == YCHK2) || (current_state == PERM1));
endmodule