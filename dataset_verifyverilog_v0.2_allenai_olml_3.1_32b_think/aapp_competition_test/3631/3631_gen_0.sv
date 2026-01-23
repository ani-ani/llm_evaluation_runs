module beacon_connectivity (
    input clk,
    input rst_n,
    input start,
    input [13:0] beacon_x [7:0],
    input [13:0] beacon_y [7:0],
    input [13:0] mountain_x [7:0],
    input [13:0] mountain_y [7:0],
    input [13:0] mountain_r [7:0],
    input [3:0] num_beacons,
    input [3:0] num_mountains,
    output reg [3:0] result,
    output reg done
);

// Registers
reg [13:0] beacon_x_reg [7:0];
reg [13:0] beacon_y_reg [7:0];
reg [13:0] mountain_x_reg [7:0];
reg [13:0] mountain_y_reg [7:0];
reg [13:0] mountain_r_reg [7:0];
reg [3:0] num_beacons_reg;
reg [3:0] num_mountains_reg;

// DSU
reg [2:0] parent [7:0];

// Counters
reg [3:0] i_cnt, j_cnt, k_cnt;
reg [2:0] state;

// Outputs
output reg [3:0] result;
output reg done;

// State encoding
localparam IDLE = 3'd0, LOAD=1, INIT=2, PAIR=3, MOUNTAIN=4, COUNT=5, DONE=6;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        beacon_x_reg <= 0;
        beacon_y_reg <=0;
        mountain_x_reg <=0;
        mountain_y_reg <=0;
        mountain_r_reg <=0;
        num_beacons_reg <=0;
        num_mountains_reg <=0;
        parent <= 0;
        i_cnt <=0; j_cnt<=0; k_cnt<=0;
        result <=0; done <=0;
    end else begin
        case (state)
            IDLE: state <= LOAD;
            LOAD: begin
                beacon_x_reg <= beacon_x;
                beacon_y_reg <= beacon_y;
                mountain_x_reg <= mountain_x;
                mountain_y_reg <= mountain_y;
                mountain_r_reg <= mountain_r;
                num_beacons_reg <= num_beacons;
                num_mountains_reg <= num_mountains;
                state <= INIT;
            end
            INIT: begin
                parent[0] <=0; parent[1]<=1; parent[2]<=2; parent[3]<=3;
                parent[4]<=4; parent[5]<=5; parent[6]<=6; parent[7]<=7;
                i_cnt <=0;
                state <= PAIR;
            end
            PAIR: begin
                if (i_cnt < num_beacons_reg) begin
                    j_cnt <= i_cnt +1;
                    k_cnt <=0;
                    state <= MOUNTAIN;
                end else begin
                    state <= COUNT;
                end
            end
            MOUNTAIN: begin
                if (k_cnt < num_mountains_reg) begin
                    k_cnt <= k_cnt +1;
                end else begin
                    j_cnt <= j_cnt +1;
                    if (j_cnt >= num_beacons_reg) begin
                        j_cnt <=0;
                        i_cnt <= i_cnt +1;
                        if (i_cnt >= num_beacons_reg) state <= COUNT;
                        else state <= MOUNTAIN;
                    end else state <= MOUNTAIN;
                end
            end
            COUNT: begin
                result <= 0;
                done <=1;
                state <= DONE;
            end
            DONE: ;
        endcase
    end
endmodule