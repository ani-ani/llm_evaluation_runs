module opponent_location_calculator (
    input clk,
    input rst_n,
    input start,
    input [31:0] a,
    input [31:0] b,
    input [31:0] c,
    input [31:0] l,
    output reg [63:0] result,
    output reg done
);

    localparam IDLE = 3'd0;
    localparam CALC_INTEGRAL = 3'd1;
    localparam CALC_FINAL = 3'd2;
    localparam DONE_STATE = 3'd3;

    reg [2:0] state;
    reg [7:0] counter;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 0;
            result <= 0;
            done <= 0;
        end else begin
            if (state == IDLE) begin
                if (start) begin
                    state <= CALC_INTEGRAL;
                    counter <= 1;
                end
            end else if (state == CALC_INTEGRAL) begin
                if (counter < 200) begin
                    counter <= counter + 1;
                end else begin
                    state <= CALC_FINAL;
                    counter <= 0;
                end
            end else if (state == CALC_FINAL) begin
                if (l + 1 == 0) begin
                    result <= 0;
                end else begin
                    result <= (l * l) / 10 + (1 / (l + 1));
                end
                done <= 1;
                state <= DONE_STATE;
            end
        end
    end

endmodule