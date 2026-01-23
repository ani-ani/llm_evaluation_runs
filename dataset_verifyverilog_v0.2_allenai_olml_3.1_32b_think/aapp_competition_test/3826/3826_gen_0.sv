module min_subsegment_removal (
    input clk,
    input rst_n,
    input start,
    input [2:0] n_in,
    input [7:0] arr_in,
    output reg [3:0] result,
    output reg done
);

reg [7:0] arr [7:0];
reg [2:0] n;
reg [3:0] min_len;
reg [2:0] l, r;
reg [2:0] l_counter, r_counter;
reg [2:0] load_counter;
reg [2:0] state;

parameter IDLE = 3'b000,
               LOAD = 3'b001,
               INIT = 3'b010,
               LOOP_L = 3'b011,
               CHECK_R = 3'b100,
               UPDATE = 3'b101,
               DONE = 3'b110;

always @(posedge clk) begin
    if (!rst_n) begin
        n <= 3'b000;
        min_len <= 4'b0000;
        l <= 3'b000;
        r <= 3'b000;
        l_counter <= 3'b000;
        r_counter <= 3'b000;
        load_counter <= 3'b000;
        state <= IDLE;
    end else begin
        case (state)
            IDLE: begin
                if (start == 1'b1) state <= LOAD;
            end
            LOAD: begin
                if (n == 3'b000) n <= n_in;
                else if (load_counter < n) begin
                    arr[load_counter] <= arr_in;
                    load_counter <= load_counter + 1;
                end else begin
                    state <= INIT;
                    min_len <= n;
                end
            end
            INIT: begin
                state <= LOOP_L;
                l_counter <= n - 1;
            end
            LOOP_L: begin
                if (l_counter < 3'b000) begin
                    l <= l_counter;
                    state <= CHECK_R;
                    r_counter <= l;
                end else begin
                    state <= DONE;
                end
            end
            CHECK_R: begin
                if (r_counter - l + 1 < min_len) begin
                    min_len <= r_counter - l + 1;
                end
                if (r_counter > n-1) begin
                    state <= LOOP_L;
                    l_counter <= l_counter - 1;
                end else begin
                    r_counter <= r_counter + 1;
                end
            end
            DONE: begin
                done <= 1'b1;
                result <= min_len;
            end
        endcase
    end
endmodule