module antimatter_collision (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] d_x [0:15],
    input wire [7:0] d_y [0:15],
    input wire [7:0] s_x1 [0:15],
    input wire [7:0] s_x2 [0:15],
    input wire [7:0] s_y [0:15],
    input wire [3:0] num_droplets,
    input wire [3:0] num_sensors,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_SENSOR = 3'd1;
    localparam [2:0] UPDATE_BEST = 3'd2;
    localparam [2:0] NEXT_DROPLET = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state;
    reg [3:0] droplet_idx;
    reg [3:0] sensor_idx;
    reg [7:0] best_y;
    reg [7:0] current_result;
    reg [3:0] cycle_counter;
    localparam [3:0] MAX_CYCLES = 4'd16;

    // Combinational signals for collision detection
    reg hit;
    wire [7:0] current_d_x;
    wire [7:0] current_d_y;
    wire [7:0] current_s_x1;
    wire [7:0] current_s_x2;
    wire [7:0] current_s_y;

    // Extract current droplet and sensor data
    assign current_d_x = d_x[droplet_idx];
    assign current_d_y = d_y[droplet_idx];
    assign current_s_x1 = s_x1[sensor_idx];
    assign current_s_x2 = s_x2[sensor_idx];
    assign current_s_y = s_y[sensor_idx];

    // Combinational hit detection
    always @(*) begin
        hit = 1'b0;
        if ((current_s_y < current_d_y) && 
            (current_s_x1 <= current_d_x) && 
            (current_d_x <= current_s_x2)) begin
            hit = 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            droplet_idx <= 4'd0;
            sensor_idx <= 4'd0;
            best_y <= 8'd0;
            current_result <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
            cycle_counter <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    droplet_idx <= 4'd0;
                    sensor_idx <= 4'd0;
                    best_y <= 8'd0;
                    current_result <= 8'd0;
                    cycle_counter <= 4'd0;
                    if (start && (num_droplets > 4'd0)) begin
                        state <= CHECK_SENSOR;
                        best_y <= 8'd0;
                    end else if (start) begin
                        state <= FINISH;
                    end
                end

                CHECK_SENSOR: begin
                    if (sensor_idx < num_sensors) begin
                        if (hit) begin
                            if (current_s_y > best_y) begin
                                state <= UPDATE_BEST;
                            end else begin
                                sensor_idx <= sensor_idx + 4'd1;
                            end
                        end else begin
                            sensor_idx <= sensor_idx + 4'd1;
                        end
                    end else begin
                        state <= NEXT_DROPLET;
                        current_result <= best_y;
                    end
                end

                UPDATE_BEST: begin
                    best_y <= current_s_y;
                    sensor_idx <= sensor_idx + 4'd1;
                    state <= CHECK_SENSOR;
                end

                NEXT_DROPLET: begin
                    droplet_idx <= droplet_idx + 4'd1;
                    sensor_idx <= 4'd0;
                    best_y <= 8'd0;
                    cycle_counter <= cycle_counter + 4'd1;
                    
                    if ((droplet_idx + 4'd1 >= num_droplets) || 
                        (cycle_counter >= MAX_CYCLES)) begin
                        state <= FINISH;
                        result <= current_result;
                    end else begin
                        state <= CHECK_SENSOR;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule