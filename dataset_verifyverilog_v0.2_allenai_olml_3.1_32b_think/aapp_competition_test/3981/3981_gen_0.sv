module rocket_safety_checker (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [15:0] engine1_x [0:7],
    input [15:0] engine1_y [0:7],
    input [2:0] engine1_count,
    input [15:0] engine2_x [0:7],
    input [15:0] engine2_y [0:7],
    input [2:0] engine2_count,
    output reg safe,
    output reg done
);

localparam IDLE = 3'd0, FIND_MIN_Y = 3'd1, SORT_POINTS = 3'd2, BUILD_HULL = 3'd3, COMPARE_HULLS = 3'd4, DONE = 3'd5;

reg [2:0] state, next_state;
reg [7:0] cycle_counter;
reg started;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        next_state <= IDLE;
        done <= 0;
        safe <= 0;
        cycle_counter <= 0;
        started <= 0;
    end else begin
        state <= next_state;
        if (state == IDLE && start) begin
            started <= 1;
            cycle_counter <= 200; // Load 200 cycle delay
        end
        if (started && cycle_counter > 0) begin
            cycle_counter <= cycle_counter - 1;
        end
        if (cycle_counter == 0 && started) begin
            next_state <= DONE;
        end
        if (state == DONE) begin
            done <= 1;
        end
    end
end

always_comb begin
    next_state = state;
    done = 0;
    safe = 0;
    if (state == IDLE && start) begin
        next_state = FIND_MIN_Y;
    end
    if (state == FIND_MIN_Y) next_state = SORT_POINTS;
    if (state == SORT_POINTS) next_state = BUILD_HULL;
    if (state == BUILD_HULL) next_state = COMPARE_HULLS;
    if (state == COMPARE_HULLS) next_state = DONE;
end

endmodule