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
localparam [4:0] SCALE_SHIFT = 16;
localparam [4:0] MAX_ITER = 16;
localparam [2:0] MAX_CARS_PER_LANE = 4;
localparam [0:0] LANE0 = 0;
localparam [0:0] LANE1 = 1;

// States
localparam [2:0] IDLE = 3'd0;
localparam [2:0] LOAD = 3'd1;
localparam [2:0] CHECK_D0 = 3'd2;
localparam [2:0] BINARY_SEARCH = 3'd3;
localparam [2:0] UPDATE_LOW_HIGH = 3'd4;
localparam [2:0] DONE = 3'd5;
localparam [2:0] IMPOSSIBLE = 3'd6;

reg [2:0] state;

// Input storage
reg [15:0] N_reg;
reg [15:0] M_reg;
reg [15:0] R_reg;
reg [1:0] car_lane_reg [0:7];
reg [15:0] car_len_reg [0:7];
reg [15:0] car_pos_reg [0:7];

// Scaled values
reg [31:0] L0_scaled;
reg [31:0] R_scaled;

// Filtered cars
reg [31:0] lane0_pos [0:MAX_CARS_PER_LANE-1];
reg [31:0] lane0_len [0:MAX_CARS_PER_LANE-1];
reg [2:0] lane0_count;
reg [31:0] lane1_pos [0:MAX_CARS_PER_LANE-1];
reg [31:0] lane1_len [0:MAX_CARS_PER_LANE-1];
reg [2:0] lane1_count;

// Binary search
reg [31:0] low;
reg [31:0] high;
reg [31:0] mid;
reg [4:0] iter_count;

// Feasibility combinational block
reg feasible_comb;

integer i;
integer j;

always @(*) begin
    feasible_comb = 1'b0;
    
    // Lane 0 intervals
    reg [31:0] lane0_start [0:4];
    reg [31:0] lane0_end [0:4];
    reg [2:0] lane0_interval_count = 3'd0;
    
    if (lane0_count == 3'd0) begin
        lane0_start[0] = 32'd0;
        lane0_end[0] = R_scaled - L0_scaled;
        if (lane0_end[0] >= lane0_start[0]) lane0_interval_count = 3'd1;
    end else begin
        // left
        reg [31:0] left_end = lane0_pos[0] - L0_scaled - mid;
        if (left_end >= 32'd0) begin
            lane0_start[0] = 32'd0;
            lane0_end[0] = left_end;
            lane0_interval_count = 3'd1;
        end
        // middle
        for (i = 0; i < lane0_count-1; i = i + 1) begin
            reg [31:0] gap_start = lane0_pos[i] + lane0_len[i] + mid;
            reg [31:0] gap_end = lane0_pos[i+1] - L0_scaled - mid;
            if (gap_end >= gap_start) begin
                lane0_start[lane0_interval_count] = gap_start;
                lane0_end[lane0_interval_count] = gap_end;
                lane0_interval_count = lane0_interval_count + 3'd1;
            end
        end
        // right
        reg [31:0] right_start = lane0_pos[lane0_count-1] + lane0_len[lane0_count-1] + mid;
        reg [31:0] right_end = R_scaled - L0_scaled;
        if (right_end >= right_start) begin
            lane0_start[lane0_interval_count] = right_start;
            lane0_end[lane0_interval_count] = right_end;
            lane0_interval_count = lane0_interval_count + 3'd1;
        end
    end
    
    // Lane 1 intervals
    reg [31:0] lane1_start [0:4];
    reg [31:0] lane1_end [0:4];
    reg [2:0] lane1_interval_count = 3'd0;
    
    if (lane1_count == 3'd0) begin
        lane1_start[0] = 32'd0;
        lane1_end[0] = R_scaled - L0_scaled;
        if (lane1_end[0] >= lane1_start[0]) lane1_interval_count = 3'd1;
    end else begin
        // left
        reg [31:0] left_end = lane1_pos[0] - L0_scaled - mid;
        if (left_end >= 32'd0) begin
            lane1_start[0] = 32'd0;
            lane1_end[0] = left_end;
            lane1_interval_count = 3'd1;
        end
        // middle
        for (i = 0; i < lane1_count-1; i = i + 1) begin
            reg [31:0] gap_start = lane1_pos[i] + lane1_len[i] + mid;
            reg [31:0] gap_end = lane1_pos[i+1] - L0_scaled - mid;
            if (gap_end >= gap_start) begin
                lane1_start[lane1_interval_count] = gap_start;
                lane1_end[lane1_interval_count] = gap_end;
                lane1_interval_count = lane1_interval_count + 3'd1;
            end
        end
        // right
        reg [31:0] right_start = lane1_pos[lane1_count-1] + lane1_len[lane1_count-1] + mid;
        reg [31:0] right_end = R_scaled - L0_scaled;
        if (right_end >= right_start) begin
            lane1_start[lane1_interval_count] = right_start;
            lane1_end[lane1_interval_count] = right_end;
            lane1_interval_count = lane1_interval_count + 3'd1;
        end
    end
    
    // Check overlap
    for (i = 0; i < lane0_interval_count; i = i + 1) begin
        for (j = 0; j < lane1_interval_count; j = j + 1) begin
            if (lane0_start[i] <= lane1_end[j] && lane1_start[j] <= lane0_end[i]) begin
                feasible_comb = 1'b1;
            end
        end
    end
end

wire feasible = feasible_comb;

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result_valid <= 1'b0;
        result_impossible <= 1'b0;
        result_safety_factor <= 32'd0;
        iter_count <= 5'd0;
    end else begin
        case (state)
            IDLE: begin
                result_valid <= 1'b0;
                if (start) state <= LOAD;
            end
            
            LOAD: begin
                // Capture inputs
                N_reg <= N;
                M_reg <= M;
                R_reg <= R;
                for (i = 0; i < 8; i = i + 1) begin
                    car_lane_reg[i] <= car_lane[i];
                    car_len_reg[i] <= car_len[i];
                    car_pos_reg[i] <= car_pos[i];
                end
                // Scale and filter
                L0_scaled <= {car_len_reg[0], 16'd0};
                R_scaled <= {R_reg, 16'd0};
                lane0_count <= 3'd0;
                lane1_count <= 3'd0;
                for (i = 1; i < 8 && i < M_reg; i = i + 1) begin
                    if (car_lane_reg[i] == LANE0 && lane0_count < MAX_CARS_PER_LANE) begin
                        lane0_pos[lane0_count] <= {car_pos_reg[i], 16'd0};
                        lane0_len[lane0_count] <= {car_len_reg[i], 16'd0};
                        lane0_count <= lane0_count + 3'd1;
                    end else if (car_lane_reg[i] == LANE1 && lane1_count < MAX_CARS_PER_LANE) begin
                        lane1_pos[lane1_count] <= {car_pos_reg[i], 16'd0};
                        lane1_len[lane1_count] <= {car_len_reg[i], 16'd0};
                        lane1_count <= lane1_count + 3'd1;
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
                    iter_count <= 5'd0;
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
                iter_count <= iter_count + 5'd1;
                state <= BINARY_SEARCH;
            end
            
            DONE: begin
                result_valid <= 1'b1;
                result_impossible <= 1'b0;
                result_safety_factor <= low;
            end
            
            IMPOSSIBLE: begin
                result_valid <= 1'b1;
                result_impossible <= 1'b1;
                result_safety_factor <= 32'd0;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule