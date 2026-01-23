module chubby_yang (
    input clk,
    input rst_n,
    input start,
    input [31:0] n,
    output reg [31:0] result,
    output reg done
);

localparam IDLE = 2'b00,
          PHASE1 = 2'b01,
          PHASE2 = 2'b10;

reg [1:0] state;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 0;
        done <= 0;
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                if (start) state <= PHASE1;
            end
            PHASE1: begin
                state <= PHASE2;
            end
            PHASE2: begin
                if (n == 0) begin
                    result <= 1;
                end else begin
                    result <= ( (n * 92682) >> 16 ) << 2;
                end
                done <= 1;
                state <= IDLE;
            end
        endcase
    end
end

endmodule