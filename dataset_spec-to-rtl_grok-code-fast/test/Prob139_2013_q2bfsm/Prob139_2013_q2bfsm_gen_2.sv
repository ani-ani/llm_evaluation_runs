module TopModule(
    input clk,
    input resetn,
    input x,
    input y,
    output reg f,
    output reg g
);

    localparam A = 3'd0;
    localparam B = 3'd1;
    localparam C = 3'd2;
    localparam D = 3'd3;
    localparam E = 3'd4;
    localparam F = 3'd5;

    reg [2:0] state;
    reg [2:0] x_shift;
    reg [1:0] y_cnt;

    always @(posedge clk) begin
        if (!resetn) begin
            state <= A;
            f <= 1'b0;
            g <= 1'b0;
            x_shift <= 3'b000;
            y_cnt <= 2'b00;
        end else begin
            case (state)
                A: begin
                    f <= 1'b0;
                    g <= 1'b0;
                    state <= B;
                end
                B: begin
                    f <= 1'b1;
                    g <= 1'b0;
                    state <= C;
                end
                C: begin
                    f <= 1'b0;
                    g <= 1'b0;
                    x_shift <= {x_shift[1:0], x};
                    if (x_shift == 3'b101) begin
                        state <= D;
                        y_cnt <= 2'b00;
                    end
                end
                D: begin
                    f <= 1'b0;
                    g <= 1'b1;
                    if (y) begin
                        state <= E;
                    end else if (y_cnt >= 2) begin
                        state <= F;
                    end
                    y_cnt <= y_cnt + 1;
                end
                E: begin
                    f <= 1'b0;
                    g <= 1'b1;
                    // Stay in E
                end
                F: begin
                    f <= 1'b0;
                    g <= 1'b0;
                    // Stay in F
                end
            endcase
        end
    end

endmodule