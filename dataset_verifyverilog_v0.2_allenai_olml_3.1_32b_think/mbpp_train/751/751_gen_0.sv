module check_min_heap (
    input clk,
    input rst_n,
    input start,
    input [7:0][15:0] arr,
    output reg is_heap,
    output reg done
);

localparam IDLE = 3'd0,
        CHECK_0 = 1,
        CHECK_1 = 2,
        CHECK_2 = 3,
        CHECK_3 = 4,
        DONE = 5;

reg [2:0] state;
reg error;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        error <= 0;
        done <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= CHECK_0;
                    error <= 0;
                end else begin
                    state <= IDLE;
                end
            end
            CHECK_0: begin
                if (arr[0] > arr[1] || arr[0] > arr[2]) begin
                    error <= 1;
                end
                state <= CHECK_1;
            end
            CHECK_1: begin
                if (arr[1] > arr[3] || arr[1] > arr[4]) begin
                    error <= 1;
                end
                state <= CHECK_2;
            end
            CHECK_2: begin
                if (arr[2] > arr[5] || arr[2] > arr[6]) begin
                    error <= 1;
                end
                state <= CHECK_3;
            end
            CHECK_3: begin
                if (arr[3] > arr[7]) begin
                    error <= 1;
                end
                state <= DONE;
            end
            DONE: begin
                state <= DONE;
                done <= 1;
            end
            default: state <= IDLE;
        endcase
    end
end

assign is_heap = done ? !error : 1'bX;

endmodule