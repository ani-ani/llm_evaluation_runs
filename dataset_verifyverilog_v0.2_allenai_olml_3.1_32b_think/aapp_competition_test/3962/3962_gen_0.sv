module chair_arrangement (
    input clk,
    input rst_n,
    input start,
    input [31:0] l_i,
    input [31:0] r_i,
    input [4:0] guest_index,
    input [4:0] n,
    output reg [39:0] result,
    output reg done
);

reg [31:0] l_arr [15:0];
reg [31:0] r_arr [15:0];

localparam IDLE = 3'd0, INPUT = 3'd1, SORT_L = 3'd2, SORT_R = 3'd3, CALCULATE = 3'd4, DONE = 3'd5;
reg [2:0] state;
reg [3:0] input_count = 0;
reg [3:0] l_sort_count = 0;
reg [3:0] r_sort_count = 0;
reg [3:0] sum_count = 0;
reg [39:0] sum_val = 0;
reg [31:0] temp_l, temp_r;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        input_count <= 0;
        l_sort_count <= 0;
        r_sort_count <= 0;
        sum_count <= 0;
        sum_val <= 0;
        done <= 0;
        l_arr[0] <= 32'd0;
        l_arr[1] <= 32'd0;
        l_arr[2] <= 32'd0;
        l_arr[3] <= 32'd0;
        l_arr[4] <= 32'd0;
        l_arr[5] <= 32'd0;
        l_arr[6] <= 32'd0;
        l_arr[7] <= 32'd0;
        l_arr[8] <= 32'd0;
        l_arr[9] <= 32'd0;
        l_arr[10] <= 32'd0;
        l_arr[11] <= 32'd0;
        l_arr[12] <= 32'd0;
        l_arr[13] <= 32'd0;
        l_arr[14] <= 32'd0;
        l_arr[15] <= 32'd0;
        r_arr[0] <= 32'd0;
        r_arr[1] <= 32'd0;
        r_arr[2] <= 32'd0;
        r_arr[3] <= 32'd0;
        r_arr[4] <= 32'd0;
        r_arr[5] <= 32'd0;
        r_arr[6] <= 32'd0;
        r_arr[7] <= 32'd0;
        r_arr[8] <= 32'd0;
        r_arr[9] <= 32'd0;
        r_arr[10] <= 32'd0;
        r_arr[11] <= 32'd0;
        r_arr[12] <= 32'd0;
        r_arr[13] <= 32'd0;
        r_arr[14] <= 32'd0;
        r_arr[15] <= 32'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start == 1) begin
                    state <= INPUT;
                end
            end
            INPUT: begin
                if (guest_index < n) begin
                    l_arr[guest_index] <= l_i;
                    r_arr[guest_index] <= r_i;
                    input_count <= input_count + 1;
                end
                if (input_count == n) begin
                    state <= SORT_L;
                end
            end
            SORT_L: begin
                if (l_sort_count < n-1) begin
                    if (l_arr[l_sort_count] > l_arr[l_sort_count + 1]) begin
                        temp_l <= l_arr[l_sort_count];
                        l_arr[l_sort_count] <= l_arr[l_sort_count + 1];
                        l_arr[l_sort_count + 1] <= temp_l;
                    end
                    l_sort_count <= l_sort_count + 1;
                end else begin
                    l_sort_count <= 0;
                    state <= SORT_R;
                end
            end
            SORT_R: begin
                if (r_sort_count < n-1) begin
                    if (r_arr[r_sort_count] > r_arr[r_sort_count + 1]) begin
                        temp_r <= r_arr[r_sort_count];
                        r_arr[r_sort_count] <= r_arr[r_sort_count + 1];
                        r_arr[r_sort_count + 1] <= temp_r;
                    end
                    r_sort_count <= r_sort_count + 1;
                end else begin
                    r_sort_count <= 0;
                    state <= CALCULATE;
                end
            end
            CALCULATE: begin
                if (sum_count < n) begin
                    sum_val <= sum_val + (l_arr[sum_count] > r_arr[sum_count] ? l_arr[sum_count] : r_arr[sum_count]);
                    sum_count <= sum_count + 1;
                end else begin
                    result <= sum_val + n;
                    done <= 1;
                    state <= DONE;
                end
            end
            DONE: begin
                // Do nothing
            end
        endcase
    end
endmodule