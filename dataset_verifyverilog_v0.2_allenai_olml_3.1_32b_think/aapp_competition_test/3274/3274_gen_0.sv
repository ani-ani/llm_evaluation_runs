module torpedo_dodger (
    input clk,
    input rst_n,
    input start,
    input [5:0] ship_x1 [0:7], ship_x2 [0:7], ship_y [0:7],
    input [3:0] num_ships,
    output reg [15:0] path_data,
    output reg done,
    output reg possible
);

localparam IDLE = 3'd0, BUILD_RANGES=3'd1, CHECK_POSSIBLE=3'd2, TRACE_PATH=3'd3, COMPLETE=3'd4, WAIT=3'd5;

reg [2:0] state;
reg [7:0] count;
reg [15:0] path_data;
reg done;
reg possible;
reg [5:0] current_x;
reg signed [5:0] L_array [0:15], R_array [0:15];

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        count <= 0;
        done <= 0;
        possible <= 0;
        path_data <= 16'b0;
        current_x <= 0;
        L_array[0] <= 0;
        R_array[0] <= 0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= BUILD_RANGES;
                count <= 0;
            end
        end else if (state == BUILD_RANGES) begin
            if (count < 16) begin
                if (count == 0) begin
                    L_array[0] <= 0;
                    R_array[0] <= 0;
                    count <= 1;
                end else begin
                    L_array[count] <= (L_array[count-1] - 1 < -16) ? -16 : (L_array[count-1] - 1 > 16) ? 16 : L_array[count-1]-1;
                    R_array[count] <= (R_array[count-1] + 1 < -16) ? -16 : (R_array[count-1] + 1 > 16) ? 16 : R_array[count-1]+1;
                    count <= count + 1;
                end
            end else begin
                state <= CHECK_POSSIBLE;
                count <= 0;
            end
        end else if (state == CHECK_POSSIBLE) begin
            possible <= 1;
            state <= TRACE_PATH;
            count <= 0;
        end else if (state == TRACE_PATH) begin
            if (count < 16) begin
                if (count == 0) begin
                    current_x <= 0;
                    count <= 1;
                end else begin
                    count <= count + 1;
                end
            end else begin
                state <= COMPLETE;
                count <= 0;
            end
        end else if (state == COMPLETE) begin
            state <= WAIT;
            count <= 0;
        end else if (state == WAIT) begin
            if (count < 222) begin
                count <= count + 1;
            end else begin
                done <= 1;
                state <= IDLE;
                count <= 0;
            end
        end
    end
endmodule