module antimatter_rain (
    input clk,
    input rst_n,
    input start,
    input [3:0] num_droplets,
    input [3:0] num_sensors,
    input [3:0] drop_x [0:7],
    input [3:0] drop_y [0:7],
    input [3:0] sensor_x1 [0:7],
    input [3:0] sensor_x2 [0:7],
    input [3:0] sensor_y [0:7],
    output reg [3:0] result [0:7],
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam READING = 3'b001;
    localparam PROCESSING = 3'b010;
    localparam WRITING = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    
    // Storage for active sensors
    reg active_sensors [0:7];
    
    // Processing registers
    reg [2:0] drop_idx;
    reg [2:0] sens_idx;
    reg [2:0] best_sensor_idx;
    reg [3:0] best_sensor_y;
    reg found_hit;
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 4'b0;
                active_sensors[i] <= 1'b1;
            end
            drop_idx <= 3'b0;
            sens_idx <= 3'b0;
            best_sensor_idx <= 3'b0;
            best_sensor_y <= 4'b0;
            found_hit <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Reset all sensors to active
                        for (i = 0; i < 8; i = i + 1) begin
                            active_sensors[i] <= 1'b1;
                            result[i] <= 4'b0;
                        end
                        drop_idx <= 3'b0;
                        state <= READING;
                    end
                end
                
                READING: begin
                    // Initialize scan for current droplet
                    sens_idx <= 3'b0;
                    best_sensor_y <= 4'b0;
                    best_sensor_idx <= 3'b0;
                    found_hit <= 1'b0;
                    state <= PROCESSING;
                end
                
                PROCESSING: begin
                    if (drop_idx < num_droplets) begin
                        // Check if we are done scanning all sensors for this droplet
                        if (sens_idx < num_sensors) begin
                            // Check if sensor is active
                            if (active_sensors[sens_idx]) begin
                                // Check if sensor y < droplet y
                                if (sensor_y[sens_idx] < drop_y[drop_idx]) begin
                                    // Check if droplet x is in range
                                    if ((drop_x[drop_idx] >= sensor_x1[sens_idx]) && 
                                        (drop_x[drop_idx] <= sensor_x2[sens_idx])) begin
                                        // Check if this is the highest sensor found so far
                                        if (sensor_y[sens_idx] > best_sensor_y) begin
                                            best_sensor_y <= sensor_y[sens_idx];
                                            best_sensor_idx <= sens_idx;
                                            found_hit <= 1'b1;
                                        end
                                    end
                                end
                            end
                            sens_idx <= sens_idx + 1'b1;
                        end else begin
                            // Finished scanning all sensors for this droplet
                            state <= WRITING;
                        end
                    end else begin
                        // All droplets processed
                        state <= DONE;
                    end
                end
                
                WRITING: begin
                    if (found_hit) begin
                        result[drop_idx] <= best_sensor_y;
                        active_sensors[best_sensor_idx] <= 1'b0; // Destroy sensor
                    end else begin
                        result[drop_idx] <= 4'b0;
                    end
                    drop_idx <= drop_idx + 1'b1;
                    state <= READING;
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
