module max_minions_attack (
    input clk,
    input rst_n,
    input start,
    input [1:0] n,
    input [3:0] m,
    input [15:0] R,
    input [15:0] village_x_0, village_y_0, village_r_0,
    input [15:0] village_x_1, village_y_1, village_r_1,
    input [15:0] minion_x_0, minion_y_0,
    input [15:0] minion_x_1, minion_y_1,
    input [15:0] minion_x_2, minion_y_2,
    input [15:0] minion_x_3, minion_y_3,
    input [15:0] minion_x_4, minion_y_4,
    input [15:0] minion_x_5, minion_y_5,
    input [15:0] minion_x_6, minion_y_6,
    input [15:0] minion_x_7, minion_y_7,
    output reg [7:0] max_count,
    output reg done
);

// Parameters
localparam MAX_VILLAGES = 2;
localparam MAX_MINIONS = 8;

// States
localparam IDLE = 3'b000;
localparam LOAD_INPUTS = 3'b001;
localparam CHECK_VILLAGE = 3'b010;
localparam CHECK_VILLAGE_DONE = 3'b011;
localparam COUNT_MINIONS = 3'b100;
localparam UPDATE_MAX = 3'b101;
localparam NEXT_CANDIDATE = 3'b110;
localparam DONE = 3'b111;

// Registers
reg [2:0] state;
reg [2:0] next_state;
reg [3:0] cand_idx;
reg [1:0] village_idx;
reg valid;
reg [7:0] current_count;
reg [31:0] R_sq;
reg [31:0] vr_plus_R_sq;
reg [31:0] dist_sq;
reg [15:0] dx, dy;
reg [7:0] cycle_count;
reg [3:0] k; // for counting loop

// Storage for inputs
reg [15:0] village_x [0:1];
reg [15:0] village_y [0:1];
reg [15:0] village_r [0:1];
reg [15:0] minion_x [0:7];
reg [15:0] minion_y [0:7];

// Combinational logic: cover count for current candidate
reg [3:0] cover_count;
reg [15:0] dx_temp, dy_temp;
reg [31:0] dsq_temp;
reg [7:0] k_idx;

always @(*) begin
    cover_count = 0;
    for (k_idx = 0; k_idx < 8; k_idx = k_idx + 1) begin
        if (k_idx < m && k_idx != cand_idx) begin
            dx_temp = (minion_x[cand_idx] > minion_x[k_idx]) ? 
                      (minion_x[cand_idx] - minion_x[k_idx]) : 
                      (minion_x[k_idx] - minion_x[cand_idx]);
            dy_temp = (minion_y[cand_idx] > minion_y[k_idx]) ? 
                      (minion_y[cand_idx] - minion_y[k_idx]) : 
                      (minion_y[k_idx] - minion_y[cand_idx]);
            dsq_temp = dx_temp * dx_temp + dy_temp * dy_temp;
            if (dsq_temp <= R_sq) begin
                cover_count = cover_count + 1;
            end
        end
    end
end

// State transition logic
always @(*) begin
    next_state = IDLE;
    case (state)
        IDLE: next_state = start ? LOAD_INPUTS : IDLE;
        LOAD_INPUTS: next_state = CHECK_VILLAGE;
        CHECK_VILLAGE: next_state = CHECK_VILLAGE_DONE;
        CHECK_VILLAGE_DONE: begin
            if (valid) begin
                next_state = COUNT_MINIONS;
            end else begin
                if (village_idx + 1 < n) begin
                    next_state = CHECK_VILLAGE;
                end else begin
                    next_state = NEXT_CANDIDATE;
                end
            end
        end
        COUNT_MINIONS: next_state = UPDATE_MAX;
        UPDATE_MAX: next_state = NEXT_CANDIDATE;
        NEXT_CANDIDATE: begin
            if (cand_idx + 1 < m) begin
                next_state = CHECK_VILLAGE;
            end else begin
                next_state = DONE;
            end
        end
        DONE: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        max_count <= 0;
        cand_idx <= 0;
        village_idx <= 0;
        valid <= 0;
        current_count <= 0;
        R_sq <= 0;
        vr_plus_R_sq <= 0;
        dx <= 0;
        dy <= 0;
        dist_sq <= 0;
        cycle_count <= 0;
        k <= 0;
        // Load inputs into arrays
        village_x[0] <= 0; village_y[0] <= 0; village_r[0] <= 0;
        village_x[1] <= 0; village_y[1] <= 0; village_r[1] <= 0;
        minion_x[0] <= 0; minion_y[0] <= 0;
        minion_x[1] <= 0; minion_y[1] <= 0;
        minion_x[2] <= 0; minion_y[2] <= 0;
        minion_x[3] <= 0; minion_y[3] <= 0;
        minion_x[4] <= 0; minion_y[4] <= 0;
        minion_x[5] <= 0; minion_y[5] <= 0;
        minion_x[6] <= 0; minion_y[6] <= 0;
        minion_x[7] <= 0; minion_y[7] <= 0;
    end else begin
        state <= next_state;
        case (state)
            IDLE: begin
                done <= 0;
                if (start) begin
                    max_count <= 0;
                    cycle_count <= 0;
                end
            end

            LOAD_INPUTS: begin
                R_sq <= R * R;
                cand_idx <= 0;
                village_idx <= 0;
                valid <= 1;
                current_count <= 0;
                // Load village inputs
                village_x[0] <= village_x_0; village_y[0] <= village_y_0; village_r[0] <= village_r_0;
                village_x[1] <= village_x_1; village_y[1] <= village_y_1; village_r[1] <= village_r_1;
                // Load minion inputs
                minion_x[0] <= minion_x_0; minion_y[0] <= minion_y_0;
                minion_x[1] <= minion_x_1; minion_y[1] <= minion_y_1;
                minion_x[2] <= minion_x_2; minion_y[2] <= minion_y_2;
                minion_x[3] <= minion_x_3; minion_y[3] <= minion_y_3;
                minion_x[4] <= minion_x_4; minion_y[4] <= minion_y_4;
                minion_x[5] <= minion_x_5; minion_y[5] <= minion_y_5;
                minion_x[6] <= minion_x_6; minion_y[6] <= minion_y_6;
                minion_x[7] <= minion_x_7; minion_y[7] <= minion_y_7;
            end

            CHECK_VILLAGE: begin
                if (minion_x[cand_idx] >= village_x[village_idx])
                    dx <= minion_x[cand_idx] - village_x[village_idx];
                else
                    dx <= village_x[village_idx] - minion_x[cand_idx];
                if (minion_y[cand_idx] >= village_y[village_idx])
                    dy <= minion_y[cand_idx] - village_y[village_idx];
                else
                    dy <= village_y[village_idx] - minion_y[cand_idx];
                vr_plus_R_sq <= (village_r[village_idx] + R) * (village_r[village_idx] + R);
            end

            CHECK_VILLAGE_DONE: begin
                dist_sq <= dx * dx + dy * dy;
                if (dist_sq < vr_plus_R_sq) begin
                    valid <= 0;
                end
                if (valid && (village_idx + 1 < n)) begin
                    village_idx <= village_idx + 1;
                end
            end

            COUNT_MINIONS: begin
                current_count <= cover_count;
            end

            UPDATE_MAX: begin
                if (current_count > max_count)
                    max_count <= current_count;
            end

            NEXT_CANDIDATE: begin
                if (cand_idx + 1 < m) begin
                    cand_idx <= cand_idx + 1;
                    village_idx <= 0;
                    valid <= 1;
                end
            end

            DONE: begin
                done <= 1;
            end

            default: begin
                // No special action needed, state is already set to IDLE by next_state logic
            end
        endcase
    end
end

endmodule