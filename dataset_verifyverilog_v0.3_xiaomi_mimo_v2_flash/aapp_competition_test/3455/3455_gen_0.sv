module autonomous_car (
    input clk,
    input rst_n,
    input start,
    input [15:0] N,
    input [15:0] M,
    input [15:0] R,
    input [1:0] car_lane [0:7],
    input [15:0] car_len [0:7],
    input [15:0] car_pos [0:7],
    output reg result_valid,
    output reg [31:0] result_safety_factor,
    output reg result_impossible
);

    // Parameters
    parameter SCALE_SHIFT = 16;
    parameter MAX_ITER = 16;
    parameter MAX_CARS_PER_LANE = 4;
    localparam [1:0] LANE0 = 2'd0;
    localparam [1:0] LANE1 = 2'd1;

    // States
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD = 4'd1;
    localparam [3:0] CHECK_D0 = 4'd2;
    localparam [3:0] BINARY_SEARCH = 4'd3;
    localparam [3:0] UPDATE_LOW_HIGH = 4'd4;
    localparam [3:0] DONE = 4'd5;
    localparam [3:0] IMPOSSIBLE = 4'd6;
    reg [3:0] state;

    // Input storage
    reg [15:0] N_reg, M_reg, R_reg;
    reg [1:0] car_lane_reg [0:7];
    reg [15:0] car_len_reg [0:7];
    reg [15:0] car_pos_reg [0:7];

    // Scaled values
    reg [31:0] L0_scaled;
    reg [31:0] R_scaled;

    // Filtered cars
    reg [31:0] lane0_pos [0:MAX_CARS_PER_LANE-1];
    reg [31:0] lane0_len [0:MAX_CARS_PER_LANE-1];
    reg [3:0] lane0_count;
    reg [31:0] lane1_pos [0:MAX_CARS_PER_LANE-1];
    reg [31:0] lane1_len [0:MAX_CARS_PER_LANE-1];
    reg [3:0] lane1_count;

    // Binary search
    reg [31:0] low, high, mid;
    reg [5:0] iter_count;

    // Feasibility combinational block
    reg feasible_comb;
    always @(*) begin
        feasible_comb = 0;
        // Lane 0 intervals
        reg [31:0] lane0_start [0:4];
        reg [31:0] lane0_end [0:4];
        reg [2:0] lane0_interval_count = 0;
        
        if (lane0_count == 0) begin
            lane0_start[0] = 0;
            lane0_end[0] = R_scaled - L0_scaled;
            if (lane0_end[0] >= lane0_start[0]) lane0_interval_count = 1;
        end else begin
            // left
            reg [31:0] left_end = lane0_pos[0] - L0_scaled - mid;
            if ($signed(left_end) >= $signed(32'd0)) begin
                lane0_start[0] = 0;
                lane0_end[0] = left_end;
                lane0_interval_count = 1;
            end
            // middle
            for (integer i = 0; i < lane0_count-1; i = i + 1) begin
                reg [31:0] gap_start = lane0_pos[i] + lane0_len[i] + mid;
                reg [31:0] gap_end = lane0_pos[i+1] - L0_scaled - mid;
                if ($signed(gap_end) >= $signed(gap_start)) begin
                    lane0_start[lane0_interval_count] = gap_start;
                    lane0_end[lane0_interval_count] = gap_end;
                    lane0_interval_count = lane0_interval_count + 1;
                end
            end
            // right
            reg [31:0] right_start = lane0_pos[lane0_count-1] + lane0_len[lane0_count-1] + mid;
            reg [31:0] right_end = R_scaled - L0_scaled;
            if ($signed(right_end) >= $signed(right_start)) begin
                lane0_start[lane0_interval_count] = right_start;
                lane0_end[lane0_interval_count] = right_end;
                lane0_interval_count = lane0_interval_count + 1;
            end
        end
        
        // Lane 1 intervals
        reg [31:0] lane1_start [0:4];
        reg [31:0] lane1_end [0:4];
        reg [2:0] lane1_interval_count = 0;
        
        if (lane1_count == 0) begin
            lane1_start[0] = 0;
            lane1_end[0] = R_scaled - L0_scaled;
            if (lane1_end[0] >= lane1_start[0]) lane1_interval_count = 1;
        end else begin
            // left
            reg [31:0] left_end = lane1_pos[0] - L0_scaled - mid;
            if ($signed(left_end) >= $signed(32'd0)) begin
                lane1_start[0] = 0;
                lane1_end[0] = left_end;
                lane1_interval_count = 1;
            end
            // middle
            for (integer i = 0; i < lane1_count-1; i = i + 1) begin
                reg [31:0] gap_start = lane1_pos[i] + lane1_len[i] + mid;
                reg [31:0] gap_end = lane1_pos[i+1] - L0_scaled - mid;
                if ($signed(gap_end) >= $signed(gap_start)) begin
                    lane1_start[lane1_interval_count] = gap_start;
                    lane1_end[lane1_interval_count] = gap_end;
                    lane1_interval_count = lane1_interval_count + 1;
                end
            end
            // right
            reg [31:0] right_start = lane1_pos[lane1_count-1] + lane1_len[lane1_count-1] + mid;
            reg [31:0] right_end = R_scaled - L0_scaled;
            if ($signed(right_end) >= $signed(right_start)) begin
                lane1_start[lane1_interval_count] = right_start;
                lane1_end[lane1_interval_count] = right_end;
                lane1_interval_count = lane1_interval_count + 1;
            end
        end
        
        // Check overlap
        for (integer i = 0; i < lane0_interval_count; i = i + 1) begin
            for (integer j = 0; j < lane1_interval_count; j = j + 1) begin
                if ($signed(lane0_start[i]) <= $signed(lane1_end[j]) && $signed(lane1_start[j]) <= $signed(lane0_end[i])) begin
                    feasible_comb = 1;
                end
            end
        end
    end

    wire feasible = feasible_comb;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 0;
            result_impossible <= 0;
            result_safety_factor <= 32'd0;
            iter_count <= 0;
            lane0_count <= 0;
            lane1_count <= 0;
            low <= 32'd0;
            high <= 32'd0;
            mid <= 32'd0;
            // Initialize arrays
            for (integer i = 0; i < 8; i = i + 1) begin
                car_lane_reg[i] <= 2'd0;
                car_len_reg[i] <= 16'd0;
                car_pos_reg[i] <= 16'd0;
            end
            for (integer i = 0; i < MAX_CARS_PER_LANE; i = i + 1) begin
                lane0_pos[i] <= 32'd0;
                lane0_len[i] <= 32'd0;
                lane1_pos[i] <= 32'd0;
                lane1_len[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 0;
                    result_impossible <= 0;
                    if (start) state <= LOAD;
                end
                
                LOAD: begin
                    // Capture inputs
                    N_reg <= N;
                    M_reg <= M;
                    R_reg <= R;
                    for (integer i = 0; i < 8; i = i + 1) begin
                        car_lane_reg[i] <= car_lane[i];
                        car_len_reg[i] <= car_len[i];
                        car_pos_reg[i] <= car_pos[i];
                    end
                    // Scale and filter
                    L0_scaled <= {car_len[0], 16'd0};
                    R_scaled <= {R, 16'd0};
                    lane0_count <= 4'd0;
                    lane1_count <= 4'd0;
                    for (integer i = 1; i < 8; i = i + 1) begin
                        if (i < M) begin
                            if (car_lane[i] == LANE0 && lane0_count < MAX_CARS_PER_LANE) begin
                                lane0_pos[lane0_count] <= {car_pos[i], 16'd0};
                                lane0_len[lane0_count] <= {car_len[i], 16'd0};
                                lane0_count <= lane0_count + 1;
                            end else if (car_lane[i] == LANE1 && lane1_count < MAX_CARS_PER_LANE) begin
                                lane1_pos[lane1_count] <= {car_pos[i], 16'd0};
                                lane1_len[lane1_count] <= {car_len[i], 16'd0};
                                lane1_count <= lane1_count + 1;
                            end
                        end
                    end
                    state <= CHECK_D0;
                end
                
                CHECK_D0: begin
                    mid <= 32'd0;
                    if (!feasible) state <= IMPOSSIBLE;
                    else begin
                        low <= 32'd0;
                        high <= R_scaled;
                        iter_count <= 0;
                        state <= BINARY_SEARCH;
                    end
                end
                
                BINARY_SEARCH: begin
                    if (iter_count >= MAX_ITER || low >= high) begin
                        state <= DONE;
                    end else begin
                        mid <= (low + high) >> 1;
                        state <= UPDATE_LOW_HIGH;
                    end
                end
                
                UPDATE_LOW_HIGH: begin
                    if (feasible) low <= mid;
                    else high <= mid - 32'd1;
                    iter_count <= iter_count + 1;
                    state <= BINARY_SEARCH;
                end
                
                DONE: begin
                    result_valid <= 1;
                    result_impossible <= 0;
                    result_safety_factor <= low;
                end
                
                IMPOSSIBLE: begin
                    result_valid <= 1;
                    result_impossible <= 1;
                    result_safety_factor <= 32'd0;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule