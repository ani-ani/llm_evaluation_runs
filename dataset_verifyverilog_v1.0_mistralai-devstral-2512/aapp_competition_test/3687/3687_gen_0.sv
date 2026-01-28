module interplanetary_fifo_simulator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] sensor_queue_map_0,
    input wire [2:0] sensor_queue_map_1,
    input wire [2:0] sensor_queue_map_2,
    input wire [2:0] sensor_queue_map_3,
    input wire [2:0] sensor_queue_map_4,
    input wire [2:0] sensor_queue_map_5,
    input wire [2:0] sensor_queue_map_6,
    input wire [2:0] sensor_queue_map_7,
    input wire [15:0] queue_capacity_0,
    input wire [15:0] queue_capacity_1,
    input wire [15:0] queue_capacity_2,
    input wire [15:0] queue_capacity_3,
    input wire [15:0] queue_capacity_4,
    input wire [15:0] queue_capacity_5,
    input wire [15:0] queue_capacity_6,
    input wire [15:0] queue_capacity_7,
    input wire [15:0] downlink_bandwidth_0,
    input wire [15:0] downlink_bandwidth_1,
    input wire [15:0] downlink_bandwidth_2,
    input wire [15:0] downlink_bandwidth_3,
    input wire [15:0] downlink_bandwidth_4,
    input wire [15:0] downlink_bandwidth_5,
    input wire [15:0] downlink_bandwidth_6,
    input wire [15:0] downlink_bandwidth_7,
    input wire [15:0] downlink_bandwidth_8,
    input wire [15:0] downlink_bandwidth_9,
    input wire [15:0] downlink_bandwidth_10,
    input wire [15:0] downlink_bandwidth_11,
    input wire [15:0] downlink_bandwidth_12,
    input wire [15:0] downlink_bandwidth_13,
    input wire [15:0] downlink_bandwidth_14,
    input wire [15:0] downlink_bandwidth_15,
    input wire [15:0] sensor_data_0,
    input wire [15:0] sensor_data_1,
    input wire [15:0] sensor_data_2,
    input wire [15:0] sensor_data_3,
    input wire [15:0] sensor_data_4,
    input wire [15:0] sensor_data_5,
    input wire [15:0] sensor_data_6,
    input wire [15:0] sensor_data_7,
    input wire [15:0] sensor_data_8,
    input wire [15:0] sensor_data_9,
    input wire [15:0] sensor_data_10,
    input wire [15:0] sensor_data_11,
    input wire [15:0] sensor_data_12,
    input wire [15:0] sensor_data_13,
    input wire [15:0] sensor_data_14,
    input wire [15:0] sensor_data_15,
    output reg result,
    output reg done,
    output reg [1:0] status
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] VALIDATE = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state;
    reg [7:0] window_counter;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Queue fill levels (16-bit each)
    reg [15:0] queue_fill_0;
    reg [15:0] queue_fill_1;
    reg [15:0] queue_fill_2;
    reg [15:0] queue_fill_3;
    reg [15:0] queue_fill_4;
    reg [15:0] queue_fill_5;
    reg [15:0] queue_fill_6;
    reg [15:0] queue_fill_7;

    // Overflow flag
    reg overflow_flag;

    // Sensor data array selection
    reg [15:0] current_sensor_data [0:15];

    // Downlink bandwidth array selection
    reg [15:0] current_bandwidth [0:15];

    // Sensor queue mapping array selection
    reg [2:0] current_sensor_queue_map [0:7];

    // Queue capacity array selection
    reg [15:0] current_queue_capacity [0:7];

    // Initialize arrays in always block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            state <= IDLE;
            window_counter <= 8'd0;
            cycle_count <= 8'd0;
            result <= 1'b0;
            done <= 1'b0;
            status <= 2'd0;
            overflow_flag <= 1'b0;

            // Reset queue fill levels
            queue_fill_0 <= 16'd0;
            queue_fill_1 <= 16'd0;
            queue_fill_2 <= 16'd0;
            queue_fill_3 <= 16'd0;
            queue_fill_4 <= 16'd0;
            queue_fill_5 <= 16'd0;
            queue_fill_6 <= 16'd0;
            queue_fill_7 <= 16'd0;

            // Initialize sensor data array
            current_sensor_data[0] <= sensor_data_0;
            current_sensor_data[1] <= sensor_data_1;
            current_sensor_data[2] <= sensor_data_2;
            current_sensor_data[3] <= sensor_data_3;
            current_sensor_data[4] <= sensor_data_4;
            current_sensor_data[5] <= sensor_data_5;
            current_sensor_data[6] <= sensor_data_6;
            current_sensor_data[7] <= sensor_data_7;
            current_sensor_data[8] <= sensor_data_8;
            current_sensor_data[9] <= sensor_data_9;
            current_sensor_data[10] <= sensor_data_10;
            current_sensor_data[11] <= sensor_data_11;
            current_sensor_data[12] <= sensor_data_12;
            current_sensor_data[13] <= sensor_data_13;
            current_sensor_data[14] <= sensor_data_14;
            current_sensor_data[15] <= sensor_data_15;

            // Initialize downlink bandwidth array
            current_bandwidth[0] <= downlink_bandwidth_0;
            current_bandwidth[1] <= downlink_bandwidth_1;
            current_bandwidth[2] <= downlink_bandwidth_2;
            current_bandwidth[3] <= downlink_bandwidth_3;
            current_bandwidth[4] <= downlink_bandwidth_4;
            current_bandwidth[5] <= downlink_bandwidth_5;
            current_bandwidth[6] <= downlink_bandwidth_6;
            current_bandwidth[7] <= downlink_bandwidth_7;
            current_bandwidth[8] <= downlink_bandwidth_8;
            current_bandwidth[9] <= downlink_bandwidth_9;
            current_bandwidth[10] <= downlink_bandwidth_10;
            current_bandwidth[11] <= downlink_bandwidth_11;
            current_bandwidth[12] <= downlink_bandwidth_12;
            current_bandwidth[13] <= downlink_bandwidth_13;
            current_bandwidth[14] <= downlink_bandwidth_14;
            current_bandwidth[15] <= downlink_bandwidth_15;

            // Initialize sensor queue mapping array
            current_sensor_queue_map[0] <= sensor_queue_map_0;
            current_sensor_queue_map[1] <= sensor_queue_map_1;
            current_sensor_queue_map[2] <= sensor_queue_map_2;
            current_sensor_queue_map[3] <= sensor_queue_map_3;
            current_sensor_queue_map[4] <= sensor_queue_map_4;
            current_sensor_queue_map[5] <= sensor_queue_map_5;
            current_sensor_queue_map[6] <= sensor_queue_map_6;
            current_sensor_queue_map[7] <= sensor_queue_map_7;

            // Initialize queue capacity array
            current_queue_capacity[0] <= queue_capacity_0;
            current_queue_capacity[1] <= queue_capacity_1;
            current_queue_capacity[2] <= queue_capacity_2;
            current_queue_capacity[3] <= queue_capacity_3;
            current_queue_capacity[4] <= queue_capacity_4;
            current_queue_capacity[5] <= queue_capacity_5;
            current_queue_capacity[6] <= queue_capacity_6;
            current_queue_capacity[7] <= queue_capacity_7;
        end else begin
            case (state)
                IDLE: begin
                    status <= 2'd0;
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        window_counter <= 8'd0;
                        cycle_count <= 8'd0;
                        overflow_flag <= 1'b0;
                    end
                end

                PROCESS: begin
                    status <= 2'd1;
                    done <= 1'b0;
                    cycle_count <= cycle_count + 8'd1;

                    // Process current window
                    if (window_counter < 16'd16) begin
                        // Add sensor data to queues
                        integer i;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (current_sensor_data[window_counter][15:0] > 16'd0) begin
                                case (current_sensor_queue_map[i])
                                    3'd0: begin
                                        if (queue_fill_0 + current_sensor_data[window_counter][15:0] > current_queue_capacity[0]) begin
                                            overflow_flag <= 1'b1;
                                        end else begin
                                            queue_fill_0 <= queue_fill_0 + current_sensor_data[window_counter][15:0];
                                        end
                                    end
                                    3'd1: begin
                                        if (queue_fill_1 + current_sensor_data[window_counter][15:0] > current_queue_capacity[1]) begin
                                            overflow_flag <= 1'b1;
                                        end else begin
                                            queue_fill_1 <= queue_fill_1 + current_sensor_data[window_counter][15:0];
                                        end
                                    end
                                    3'd2: begin
                                        if (queue_fill_2 + current_sensor_data[window_counter][15:0] > current_queue_capacity[2]) begin
                                            overflow_flag <= 1'b1;
                                        end else begin
                                            queue_fill_2 <= queue_fill_2 + current_sensor_data[window_counter][15:0];
                                        end
                                    end
                                    3'd3: begin
                                        if (queue_fill_3 + current_sensor_data[window_counter][15:0] > current_queue_capacity[3]) begin
                                            overflow_flag <= 1'b1;
                                        end else begin
                                            queue_fill_3 <= queue_fill_3 + current_sensor_data[window_counter][15:0];
                                        end
                                    end
                                    3'd4: begin
                                        if (queue_fill_4 + current_sensor_data[window_counter][15:0] > current_queue_capacity[4]) begin
                                            overflow_flag <= 1'b1;
                                        end else begin
                                            queue_fill_4 <= queue_fill_4 + current_sensor_data[window_counter][15:0];
                                        end
                                    end
                                    3'd5: begin
                                        if (queue_fill_5 + current_sensor_data[window_counter][15:0] > current_queue_capacity[5]) begin
                                            overflow_flag <= 1'b1;
                                        end else begin
                                            queue_fill_5 <= queue_fill_5 + current_sensor_data[window_counter][15:0];
                                        end
                                    end
                                    3'd6: begin
                                        if (queue_fill_6 + current_sensor_data[window_counter][15:0] > current_queue_capacity[6]) begin
                                            overflow_flag <= 1'b1;
                                        end else begin
                                            queue_fill_6 <= queue_fill_6 + current_sensor_data[window_counter][15:0];
                                        end
                                    end
                                    3'd7: begin
                                        if (queue_fill_7 + current_sensor_data[window_counter][15:0] > current_queue_capacity[7]) begin
                                            overflow_flag <= 1'b1;
                                        end else begin
                                            queue_fill_7 <= queue_fill_7 + current_sensor_data[window_counter][15:0];
                                        end
                                    end
                                    default: ;
                                endcase
                            end
                        end

                        // Transfer data from queues
                        reg [15:0] remaining_bandwidth;
                        remaining_bandwidth = current_bandwidth[window_counter];

                        // Prioritize high-index queues
                        if (remaining_bandwidth > queue_fill_7) begin
                            remaining_bandwidth = remaining_bandwidth - queue_fill_7;
                            queue_fill_7 <= 16'd0;
                        end else begin
                            queue_fill_7 <= queue_fill_7 - remaining_bandwidth;
                            remaining_bandwidth = 16'd0;
                        end

                        if (remaining_bandwidth > queue_fill_6) begin
                            remaining_bandwidth = remaining_bandwidth - queue_fill_6;
                            queue_fill_6 <= 16'd0;
                        end else begin
                            queue_fill_6 <= queue_fill_6 - remaining_bandwidth;
                            remaining_bandwidth = 16'd0;
                        end

                        if (remaining_bandwidth > queue_fill_5) begin
                            remaining_bandwidth = remaining_bandwidth - queue_fill_5;
                            queue_fill_5 <= 16'd0;
                        end else begin
                            queue_fill_5 <= queue_fill_5 - remaining_bandwidth;
                            remaining_bandwidth = 16'd0;
                        end

                        if (remaining_bandwidth > queue_fill_4) begin
                            remaining_bandwidth = remaining_bandwidth - queue_fill_4;
                            queue_fill_4 <= 16'd0;
                        end else begin
                            queue_fill_4 <= queue_fill_4 - remaining_bandwidth;
                            remaining_bandwidth = 16'd0;
                        end

                        if (remaining_bandwidth > queue_fill_3) begin
                            remaining_bandwidth = remaining_bandwidth - queue_fill_3;
                            queue_fill_3 <= 16'd0;
                        end else begin
                            queue_fill_3 <= queue_fill_3 - remaining_bandwidth;
                            remaining_bandwidth = 16'd0;
                        end

                        if (remaining_bandwidth > queue_fill_2) begin
                            remaining_bandwidth = remaining_bandwidth - queue_fill_2;
                            queue_fill_2 <= 16'd0;
                        end else begin
                            queue_fill_2 <= queue_fill_2 - remaining_bandwidth;
                            remaining_bandwidth = 16'd0;
                        end

                        if (remaining_bandwidth > queue_fill_1) begin
                            remaining_bandwidth = remaining_bandwidth - queue_fill_1;
                            queue_fill_1 <= 16'd0;
                        end else begin
                            queue_fill_1 <= queue_fill_1 - remaining_bandwidth;
                            remaining_bandwidth = 16'd0;
                        end

                        if (remaining_bandwidth > queue_fill_0) begin
                            remaining_bandwidth = remaining_bandwidth - queue_fill_0;
                            queue_fill_0 <= 16'd0;
                        end else begin
                            queue_fill_0 <= queue_fill_0 - remaining_bandwidth;
                            remaining_bandwidth = 16'd0;
                        end

                        // Move to next window
                        window_counter <= window_counter + 8'd1;

                        // Check if all windows processed
                        if (window_counter == 16'd16 || overflow_flag || cycle_count >= MAX_CYCLES) begin
                            state <= VALIDATE;
                        end
                    end else begin
                        state <= VALIDATE;
                    end
                end

                VALIDATE: begin
                    status <= 2'd1;
                    done <= 1'b0;

                    // Check for overflow
                    if (overflow_flag) begin
                        result <= 1'b0;
                        status <= 2'd2;
                    end else begin
                        // Check if all queues are empty
                        if (queue_fill_0 == 16'd0 && queue_fill_1 == 16'd0 && 
                            queue_fill_2 == 16'd0 && queue_fill_3 == 16'd0 && 
                            queue_fill_4 == 16'd0 && queue_fill_5 == 16'd0 && 
                            queue_fill_6 == 16'd0 && queue_fill_7 == 16'd0) begin
                            result <= 1'b1;
                            status <= 2'd3;
                        end else begin
                            result <= 1'b0;
                            status <= 2'd2;
                        end
                    end

                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    status <= 2'd1;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    status <= 2'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule