module planetoids(
    input clk,
    input rst_n,
    input start,
    input [3:0] config_addr,
    input [63:0] config_data,
    input [3:0] num_planetoids,
    output reg [15:0] result_mass,
    output reg signed [15:0] result_vx,
    output reg signed [15:0] result_vy,
    output reg signed [15:0] result_vz,
    output reg [7:0] result_x,
    output reg [7:0] result_y,
    output reg [7:0] result_z,
    output reg [3:0] result_idx,
    output reg result_valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CONFIG = 3'd1;
    localparam [2:0] RUN = 3'd2;
    localparam [2:0] REPORT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Planetoid data structures
    reg [7:0] mass [0:15];
    reg signed [15:0] vx [0:15];
    reg signed [15:0] vy [0:15];
    reg signed [15:0] vz [0:15];
    reg [7:0] x [0:15];
    reg [7:0] y [0:15];
    reg [7:0] z [0:15];
    reg active [0:15];

    // Configuration control
    reg [3:0] config_count;
    reg [3:0] config_expected;

    // Simulation control
    reg [9:0] time_step;
    localparam [9:0] MAX_TIME_STEPS = 10'd1024;
    reg collision_detected;

    // Reporting control
    reg [3:0] report_idx;
    reg [3:0] report_count;
    reg [3:0] report_total;

    // Temporary variables for collision detection
    reg [3:0] i, j;
    reg collision_occurred;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            config_count <= 4'd0;
            config_expected <= 4'd0;
            time_step <= 10'd0;
            collision_detected <= 1'b0;
            report_idx <= 4'd0;
            report_count <= 4'd0;
            report_total <= 4'd0;
            result_valid <= 1'b0;
            done <= 1'b0;

            // Initialize all planetoids
            for (i = 0; i < 16; i = i + 1) begin
                mass[i] <= 8'd0;
                vx[i] <= 16'd0;
                vy[i] <= 16'd0;
                vz[i] <= 16'd0;
                x[i] <= 8'd0;
                y[i] <= 8'd0;
                z[i] <= 8'd0;
                active[i] <= 1'b0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        config_expected <= num_planetoids;
                        config_count <= 4'd0;
                        next_state <= CONFIG;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CONFIG: begin
                    if (config_count < config_expected) begin
                        // Latch configuration data
                        mass[config_addr] <= config_data[7:0];
                        x[config_addr] <= config_data[39:32];
                        y[config_addr] <= config_data[47:40];
                        z[config_addr] <= config_data[55:48];
                        vx[config_addr] <= config_data[15:0];
                        vy[config_addr] <= config_data[31:16];
                        vz[config_addr] <= config_data[47:32];
                        active[config_addr] <= config_data[63];
                        config_count <= config_count + 4'd1;
                        next_state <= CONFIG;
                    end else begin
                        next_state <= RUN;
                        time_step <= 10'd0;
                        collision_detected <= 1'b0;
                    end
                end

                RUN: begin
                    // Check for collisions
                    collision_occurred = 1'b0;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (active[i]) begin
                            for (j = i + 1; j < 16; j = j + 1) begin
                                if (active[j] && (x[i] == x[j]) && (y[i] == y[j]) && (z[i] == z[j])) begin
                                    // Collision detected - merge j into i
                                    mass[i] <= mass[i] + mass[j];
                                    vx[i] <= (vx[i] + vx[j]) >> 1;
                                    vy[i] <= (vy[i] + vy[j]) >> 1;
                                    vz[i] <= (vz[i] + vz[j]) >> 1;
                                    active[j] <= 1'b0;
                                    collision_occurred = 1'b1;
                                end
                            end
                        end
                    end

                    // Update positions for all active planetoids
                    for (i = 0; i < 16; i = i + 1) begin
                        if (active[i]) begin
                            x[i] <= (x[i] + vx[i][7:0]) % 8'd8;
                            y[i] <= (y[i] + vy[i][7:0]) % 8'd8;
                            z[i] <= (z[i] + vz[i][7:0]) % 8'd8;
                        end
                    end

                    // Update time step and check termination
                    time_step <= time_step + 10'd1;
                    if (collision_occurred) begin
                        collision_detected <= 1'b1;
                    end

                    // Check termination conditions
                    if ((!collision_occurred && collision_detected) || (time_step >= MAX_TIME_STEPS)) begin
                        next_state <= REPORT;
                        report_count <= 4'd0;
                        report_total <= 4'd0;
                        // Count active planetoids
                        for (i = 0; i < 16; i = i + 1) begin
                            if (active[i]) begin
                                report_total <= report_total + 4'd1;
                            end
                        end
                        // Sort planetoids by mass (descending) and position (lexicographic)
                        // This is a simplified sorting approach
                        for (i = 0; i < 15; i = i + 1) begin
                            for (j = i + 1; j < 16; j = j + 1) begin
                                if (active[i] && active[j] && 
                                    (mass[i] < mass[j] ||
                                     (mass[i] == mass[j] && 
                                      (x[i] > x[j] || (x[i] == x[j] && (y[i] > y[j] || (y[i] == y[j] && z[i] > z[j]))))))) begin
                                    // Swap i and j
                                    reg [7:0] temp_mass;
                                    reg signed [15:0] temp_vx, temp_vy, temp_vz;
                                    reg [7:0] temp_x, temp_y, temp_z;
                                    reg temp_active;

                                    temp_mass = mass[i];
                                    mass[i] = mass[j];
                                    mass[j] = temp_mass;

                                    temp_vx = vx[i];
                                    vx[i] = vx[j];
                                    vx[j] = temp_vx;

                                    temp_vy = vy[i];
                                    vy[i] = vy[j];
                                    vy[j] = temp_vy;

                                    temp_vz = vz[i];
                                    vz[i] = vz[j];
                                    vz[j] = temp_vz;

                                    temp_x = x[i];
                                    x[i] = x[j];
                                    x[j] = temp_x;

                                    temp_y = y[i];
                                    y[i] = y[j];
                                    y[j] = temp_y;

                                    temp_z = z[i];
                                    z[i] = z[j];
                                    z[j] = temp_z;

                                    temp_active = active[i];
                                    active[i] = active[j];
                                    active[j] = temp_active;
                                end
                            end
                        end
                    end else begin
                        next_state <= RUN;
                    end
                end

                REPORT: begin
                    if (report_count < report_total) begin
                        result_mass <= mass[report_count];
                        result_vx <= vx[report_count];
                        result_vy <= vy[report_count];
                        result_vz <= vz[report_count];
                        result_x <= x[report_count];
                        result_y <= y[report_count];
                        result_z <= z[report_count];
                        result_idx <= report_count;
                        result_valid <= 1'b1;
                        report_count <= report_count + 4'd1;
                        next_state <= REPORT;
                    end else begin
                        result_valid <= 1'b0;
                        done <= 1'b1;
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    result_valid <= 1'b0;
                    if (start) begin
                        next_state <= IDLE;
                        done <= 1'b0;
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    result_valid <= 1'b0;
                end
            endcase
        end
    end

endmodule