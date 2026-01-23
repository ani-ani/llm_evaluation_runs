module mps_system(
    input clk,
    input rst_n,
    input start,
    input [1:0] num_beacons,
    input signed [7:0] beacon0_x,
    input signed [7:0] beacon0_y,
    input [13:0] beacon0_d,
    input signed [7:0] beacon1_x,
    input signed [7:0] beacon1_y,
    input [13:0] beacon1_d,
    input signed [7:0] beacon2_x,
    input signed [7:0] beacon2_y,
    input [13:0] beacon2_d,
    input signed [7:0] beacon3_x,
    input signed [7:0] beacon3_y,
    input [13:0] beacon3_d,
    output reg [3:0] result_x,
    output reg [3:0] result_y,
    output reg done,
    output reg impossible,
    output reg uncertain
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SEARCH = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] candidate_x, candidate_y;
    reg [2:0] beacon_idx;
    reg [2:0] solution_count;
    reg [3:0] first_x, first_y;
    reg [15:0] clk_counter;
    localparam [15:0] MAX_CYCLES = 16'd1000;

    // Beacon storage
    wire signed [7:0] beacon_x [0:3];
    wire signed [7:0] beacon_y [0:3];
    wire [13:0] beacon_d [0:3];

    assign beacon_x[0] = beacon0_x;
    assign beacon_y[0] = beacon0_y;
    assign beacon_d[0] = beacon0_d;
    assign beacon_x[1] = beacon1_x;
    assign beacon_y[1] = beacon1_y;
    assign beacon_d[1] = beacon1_d;
    assign beacon_x[2] = beacon2_x;
    assign beacon_y[2] = beacon2_y;
    assign beacon_d[2] = beacon2_d;
    assign beacon_x[3] = beacon3_x;
    assign beacon_y[3] = beacon3_y;
    assign beacon_d[3] = beacon3_d;

    // Manhattan distance calculation
    wire signed [8:0] dx = candidate_x - beacon_x[beacon_idx];
    wire signed [8:0] dy = candidate_y - beacon_y[beacon_idx];
    wire signed [8:0] abs_dx = dx[8] ? -dx : dx;
    wire signed [8:0] abs_dy = dy[8] ? -dy : dy;
    wire [13:0] calc_dist = abs_dx + abs_dy;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_x <= 4'd0;
            result_y <= 4'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            uncertain <= 1'b0;
            candidate_x <= 4'd0;
            candidate_y <= 4'd0;
            beacon_idx <= 3'd0;
            solution_count <= 3'd0;
            first_x <= 4'd0;
            first_y <= 4'd0;
            clk_counter <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    uncertain <= 1'b0;
                    clk_counter <= 16'd0;
                    if (start) begin
                        state <= SEARCH;
                        candidate_x <= 4'd0;
                        candidate_y <= 4'd0;
                        beacon_idx <= 3'd0;
                        solution_count <= 3'd0;
                        first_x <= 4'd0;
                        first_y <= 4'd0;
                    end
                end

                SEARCH: begin
                    clk_counter <= clk_counter + 16'd1;
                    if (clk_counter >= MAX_CYCLES) begin
                        state <= FINISH;
                        impossible <= 1'b1;
                    end else if (beacon_idx < num_beacons) begin
                        if (calc_dist == beacon_d[beacon_idx]) begin
                            beacon_idx <= beacon_idx + 3'd1;
                        end else begin
                            beacon_idx <= 3'd0;
                            if (candidate_x == 4'd7) begin
                                candidate_x <= 4'd0;
                                if (candidate_y == 4'd7) begin
                                    state <= FINISH;
                                end else begin
                                    candidate_y <= candidate_y + 4'd1;
                                end
                            end else begin
                                candidate_x <= candidate_x + 4'd1;
                            end
                        end
                    end else begin
                        solution_count <= solution_count + 3'd1;
                        if (solution_count == 3'd1) begin
                            first_x <= candidate_x;
                            first_y <= candidate_y;
                        end
                        beacon_idx <= 3'd0;
                        if (candidate_x == 4'd7) begin
                            candidate_x <= 4'd0;
                            if (candidate_y == 4'd7) begin
                                state <= FINISH;
                            end else begin
                                candidate_y <= candidate_y + 4'd1;
                            end
                        end else begin
                            candidate_x <= candidate_x + 4'd1;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    if (solution_count == 3'd0) begin
                        impossible <= 1'b1;
                    end else if (solution_count > 3'd1) begin
                        uncertain <= 1'b1;
                    end else begin
                        result_x <= first_x;
                        result_y <= first_y;
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule