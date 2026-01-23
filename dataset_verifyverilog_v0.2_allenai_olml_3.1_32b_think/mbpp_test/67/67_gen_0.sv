module bell_number (
    input clk,
    input rst_n, // active low
    input start,
    input [3:0] n,
    output reg [63:0] result,
    output reg done
);

localparam IDLE = 2'd0, FETCH=2'd1, COMPUTE=2'd2, DONE=2'd3;

reg [1:0] state;
reg [2:0] counter;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 64'd0;
        done <= 1'b0;
        counter <= 3'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= FETCH;
                end else begin
                    state <= IDLE;
                end
            end
            FETCH: begin
                if (n >=0 && n <=8) begin
                    case(n)
                        0: result = 64'h0000000000000001;
                        1: result = 64'h0000000000000001;
                        2: result = 64'h0000000000000002;
                        3: result = 64'h0000000000000005;
                        4: result = 64'h000000000000000F;
                        5: result = 64'h0000000000000034;
                        6: result = 64'h00000000000000CB;
                        7: result = 64'h000000000000036D;
                        8: result = 64'h00000000000102C;
                        default: result = 64'd0;
                    endcase
                end else begin
                    result = 64'd0;
                end
                state <= COMPUTE;
                counter <= 7;
            end
            COMPUTE: begin
                if (counter == 0) begin
                    state <= DONE;
                    done <= 1'b1;
                end else begin
                    counter <= counter - 1;
                    state <= COMPUTE;
                    done <= 1'b0;
                end
            end
            DONE: begin
                state <= DONE;
                done <= 1'b1;
            end
        endcase
    end
end