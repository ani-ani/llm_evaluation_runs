module rotation_counter(input clk, input rst_n, input start, input [3:0] n, input signed [15:0] arr [0:15], output reg [3:0] rotations, output reg done);
reg [3:0] stored_n;
reg signed [15:0] stored_arr [0:15];
reg [3:0] left, right;
reg [3:0] rotations;
reg [2:0] state;
localparam IDLE = 3'd0, COMPARE = 3'd1, UPDATE_LEFT = 3'd2, UPDATE_RIGHT = 3'd3, DONE = 3'd4;
always @(posedge clk) begin
    if (!rst_n) begin
        stored_n <= 4'd0;
        stored_arr <= 16'd0;
        left <= 4'd0;
        right <= 4'd0;
        rotations <= 4'd0;
        done <= 1'b0;
        state <= IDLE;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    stored_n <= n;
                    stored_arr <= arr;
                    if (stored_arr[0] <= stored_arr[stored_n - 1]) begin
                        rotations <= 4'd0;
                        done <= 1'b1;
                        state <= DONE;
                    end else begin
                        left <= 4'd0;
                        right <= stored_n - 1;
                        state <= COMPARE;
                    end
                end else begin
                    state <= IDLE;
                end
            end
            COMPARE: begin
                integer mid;
                mid = (left + right) >> 1;
                if (stored_arr[mid] > stored_arr[right]) begin
                    state <= UPDATE_LEFT;
                end else begin
                    state <= UPDATE_RIGHT;
                end
            end
            UPDATE_LEFT: begin
                integer mid;
                mid = (left + right) >> 1;
                left <= mid + 1;
                if (left < right) begin
                    state <= COMPARE;
                end else begin
                    rotations <= left;
                    state <= DONE;
                end
            end
            UPDATE_RIGHT: begin
                integer mid;
                mid = (left + right) >> 1;
                right <= mid;
                if (left < right) begin
                    state <= COMPARE;
                end else begin
                    rotations <= left;
                    state <= DONE;
                end
            end
            DONE: begin
                state <= DONE;
            end
        endcase
    end
endmodule