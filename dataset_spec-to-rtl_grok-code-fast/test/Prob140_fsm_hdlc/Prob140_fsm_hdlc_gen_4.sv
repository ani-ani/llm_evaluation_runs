module TopModule(
    input clk,
    input reset,
    input in,
    output reg disc,
    output reg flag,
    output reg err
);

    reg [2:0] state;

    always @(posedge clk) begin
        if (reset) begin
            state <= 3'd0;
            disc <= 1'b0;
            flag <= 1'b0;
            err <= 1'b0;
        end else begin
            if (in == 1'b1) begin
                if (state < 3'd7) begin
                    state <= state + 1;
                end else begin
                    state <= 3'd7;
                end
            end else begin
                state <= 3'd0;
            end

            if (in == 1'b0 && state == 3'd5) begin
                disc <= 1'b1;
            end else begin
                disc <= 1'b0;
            end

            if (in == 1'b0 && state == 3'd6) begin
                flag <= 1'b1;
            end else begin
                flag <= 1'b0;
            end

            if (in == 1'b1 && state == 3'd6) begin
                err <= 1'b1;
            end else begin
                err <= 1'b0;
            end
        end
    end

endmodule