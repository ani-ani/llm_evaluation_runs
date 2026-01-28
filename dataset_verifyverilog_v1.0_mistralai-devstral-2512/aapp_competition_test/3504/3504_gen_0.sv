module AntimatterCollision(
    input clk,
    input rst_n,
    input start,
    input [7:0] d_x [0:15],
    input [7:0] d_y [0:15],
    input [7:0] s_x1 [0:15],
    input [7:0] s_x2 [0:15],
    input [7:0] s_y [0:15],
    input [3:0] num_droplets,
    input [3:0] num_sensors,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] PROCESS = 4'd1;
    localparam [3:0] FINISH = 4'd2;

    reg [3:0] state;
    reg [3:0] droplet_idx;
    reg [3:0] sensor_idx;
    reg [7:0] max_y;
    reg [7:0] current_d_x;
    reg [7:0] current_d_y;
    reg found;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            droplet_idx <= 4'd0;
            sensor_idx <= 4'd0;
            max_y <= 8'd0;
            current_d_x <= 8'd0;
            current_d_y <= 8'd0;
            found <= 1'b0;
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        droplet_idx <= 4'd0;
                        sensor_idx <= 4'd0;
                        max_y <= 8'd0;
                        found <= 1'b0;
                        current_d_x <= d_x[0];
                        current_d_y <= d_y[0];
                    end
                end

                PROCESS: begin
                    // Check if we've processed all droplets
                    if (droplet_idx >= num_droplets) begin
                        state <= FINISH;
                    end else begin
                        // Check if we've processed all sensors for current droplet
                        if (sensor_idx >= num_sensors) begin
                            // Move to next droplet
                            droplet_idx <= droplet_idx + 4'd1;
                            sensor_idx <= 4'd0;
                            max_y <= 8'd0;
                            found <= 1'b0;
                            if (droplet_idx < num_droplets) begin
                                current_d_x <= d_x[droplet_idx];
                                current_d_y <= d_y[droplet_idx];
                            end
                        end else begin
                            // Check collision with current sensor
                            if (s_y[sensor_idx] < current_d_y && 
                                s_x1[sensor_idx] <= current_d_x &&
                                current_d_x <= s_x2[sensor_idx]) begin
                                if (!found || s_y[sensor_idx] > max_y) begin
                                    max_y <= s_y[sensor_idx];
                                    found <= 1'b1;
                                end
                            end
                            sensor_idx <= sensor_idx + 4'd1;
                        end
                    end
                end

                FINISH: begin
                    if (found) begin
                        result <= max_y;
                    end else begin
                        result <= 8'd0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule