module ranger_strength_op (
    input clk,
    input rst_n, // active low reset
    input start,
    input [9:0] x,
    input [7:0][9:0] data_in,
    output reg [9:0] max_out,
    output reg [9:0] min_out,
    output reg done
);

localparam MAX_ITER = 16;

reg [9:0] arr [7:0];
reg [7:0] iter_count;
reg [2:0] state;
reg [2:0] sort_pass;
reg [2:0] current_i;
reg [9:0] temp;

localparam IDLE = 3'd0,
SORTING = 3'd1,
XORING = 3'd2,
UPDATE_K = 3'd3,
FINISHED = 3'd4;

always_ff @(posedge clk)
    if (!rst_n) begin
        arr <= 8'd0;
        iter_count <= 8'd0;
        sort_pass <= 3'd0;
        current_i <= 3'd0;
        state <= IDLE;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    arr <= data_in;
                    iter_count <= MAX_ITER;
                    state <= SORTING;
                end else begin
                    state <= IDLE;
                end
            end
            SORTING: begin
                if (current_i < 7) begin
                    if (arr[current_i] > arr[current_i + 1]) begin
                        temp = arr[current_i];
                        arr[current_i] = arr[current_i + 1];
                        arr[current_i + 1] = temp;
                    end
                    current_i <= current_i + 1;
                end else begin
                    current_i <= 3'd0;
                    if (sort_pass < 6) begin
                        sort_pass <= sort_pass + 1;
                    end else begin
                        state <= XORING;
                    end
                end
            end
            XORING: begin
                arr[0] <= arr[0] ^ x;
                arr[2] <= arr[2] ^ x;
                arr[4] <= arr[4] ^ x;
                arr[6] <= arr[6] ^ x;
                state <= UPDATE_K;
            end
            UPDATE_K: begin
                if (iter_count > 0) begin
                    iter_count <= iter_count - 1;
                    state <= SORTING;
                end else begin
                    state <= FINISHED;
                end
            end
            FINISHED: state <= FINISHED;
        endcase
    end

always @(*) begin
    max_out = 'd0;
    min_out = 'd0;
    done = 1'b0;
    if (state == FINISHED) begin
        max_out = arr[0];
        min_out = arr[0];
        if (arr[1] > max_out) max_out = arr[1];
        if (arr[1] < min_out) min_out = arr[1];
        if (arr[2] > max_out) max_out = arr[2];
        if (arr[2] < min_out) min_out = arr[2];
        if (arr[3] > max_out) max_out = arr[3];
        if (arr[3] < min_out) min_out = arr[3];
        if (arr[4] > max_out) max_out = arr[4];
        if (arr[4] < min_out) min_out = arr[4];
        if (arr[5] > max_out) max_out = arr[5];
        if (arr[5] < min_out) min_out = arr[5];
        if (arr[6] > max_out) max_out = arr[6];
        if (arr[6] < min_out) min_out = arr[6];
        if (arr[7] > max_out) max_out = arr[7];
        if (arr[7] < min_out) min_out = arr[7];
        done = 1'b1;
    end
end

endmodule