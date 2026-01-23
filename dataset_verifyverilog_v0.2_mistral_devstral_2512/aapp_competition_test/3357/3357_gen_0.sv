module sunlight_hours (
    input clk,
    input rst_n,
    input start,
    input [2:0] n_valid,
    input [15:0] x_data [0:7],
    input [15:0] h_data [0:7],
    output reg [15:0] sun_hours [0:7],
    output reg done
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        LOAD,
        SWEEP_WEST,
        SWEEP_EAST,
        CALC,
        DONE_STATE
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg [2:0] n;
    reg [2:0] i, j;
    reg [31:0] max_slope_west [0:7];
    reg [31:0] max_slope_east [0:7];
    reg [31:0] slope;
    reg [31:0] dh, dx;
    reg [31:0] temp;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            LOAD: begin
                next_state = SWEEP_WEST;
            end
            SWEEP_WEST: begin
                if (i == n) next_state = SWEEP_EAST;
            end
            SWEEP_EAST: begin
                if (i == n) next_state = CALC;
            end
            CALC: begin
                if (i == n) next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            n <= 0;
            i <= 0;
            j <= 0;
            for (int k = 0; k < 8; k++) begin
                max_slope_west[k] <= 0;
                max_slope_east[k] <= 0;
                sun_hours[k] <= 0;
            end
        end else begin
            case (state)
                LOAD: begin
                    n <= n_valid;
                    i <= 0;
                    j <= 0;
                end
                SWEEP_WEST: begin
                    if (j < i) begin
                        dh = h_data[i] - h_data[j];
                        dx = x_data[i] - x_data[j];
                        if (dx != 0) begin
                            slope = (dh << 16) / dx;
                            if (slope > max_slope_west[i]) begin
                                max_slope_west[i] <= slope;
                            end
                        end
                        j <= j + 1;
                    end else begin
                        j <= 0;
                        i <= i + 1;
                    end
                end
                SWEEP_EAST: begin
                    if (j < i) begin
                        dh = h_data[j] - h_data[i];
                        dx = x_data[i] - x_data[j];
                        if (dx != 0) begin
                            slope = (dh << 16) / dx;
                            if (slope > max_slope_east[i]) begin
                                max_slope_east[i] <= slope;
                            end
                        end
                        j <= j + 1;
                    end else begin
                        j <= 0;
                        i <= i + 1;
                    end
                end
                CALC: begin
                    temp = (max_slope_west[i] + max_slope_east[i]) >> 16;
                    sun_hours[i] <= 0x120000 - temp;
                    i <= i + 1;
                end
                DONE_STATE: begin
                    done <= 1;
                end
                default: begin
                    done <= 0;
                end
            endcase
        end
    end

endmodule