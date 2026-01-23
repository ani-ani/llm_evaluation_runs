module traffic_scheduler (
    input clk,
    input rst_n,
    input start,
    input [7:0] car_idx,
    input car_dir,
    input [15:0] car_arrival,
    input [15:0] car_irritation,
    output reg [3:0] result_min_irritated,
    output reg done
);

    // Parameters
    localparam t_pass = 8;
    localparam max_cars = 8;
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam PROCESSING = 3'b010;
    localparam CALCULATING = 3'b100;
    localparam DONE = 3'b101;

    // Internal registers
    reg [2:0] state;
    reg [7:0] load_idx;
    reg [15:0] cars_arrival [0:max_cars-1];
    reg cars_dir [0:max_cars-1];
    reg [15:0] cars_irritation [0:max_cars-1];
    reg [15:0] current_time;
    reg current_direction;
    reg [3:0] irritated_count;
    reg [2:0] schedule_state;
    reg [3:0] best_irritated;
    reg [7:0] schedule_idx;
    reg [6:0] switch_pattern;
    reg [2:0] car_process_idx;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_idx <= 0;
            current_time <= 0;
            current_direction <= 0;
            irritated_count <= 0;
            schedule_state <= 0;
            best_irritated <= 0;
            schedule_idx <= 0;
            switch_pattern <= 0;
            car_process_idx <= 0;
            done <= 0;
            result_min_irritated <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD;
                        load_idx <= 0;
                    end
                end
                LOAD: begin
                    if (load_idx == max_cars - 1) begin
                        state <= PROCESSING;
                        schedule_idx <= 0;
                        switch_pattern <= 0;
                        best_irritated <= 8;
                    end else begin
                        cars_arrival[load_idx] <= car_arrival;
                        cars_dir[load_idx] <= car_dir;
                        cars_irritation[load_idx] <= car_irritation;
                        load_idx <= load_idx + 1;
                    end
                end
                PROCESSING: begin
                    if (schedule_idx == 127) begin
                        state <= CALCULATING;
                    end else begin
                        current_time <= 0;
                        current_direction <= 0;
                        irritated_count <= 0;
                        car_process_idx <= 0;
                        schedule_state <= 0;
                        schedule_idx <= schedule_idx + 1;
                        switch_pattern <= schedule_idx;
                    end
                end
                CALCULATING: begin
                    if (car_process_idx == max_cars - 1) begin
                        if (irritated_count < best_irritated) begin
                            best_irritated <= irritated_count;
                        end
                        if (schedule_idx == 127) begin
                            state <= DONE;
                            done <= 1;
                            result_min_irritated <= best_irritated;
                        end else begin
                            state <= PROCESSING;
                        end
                    end else begin
                        // Process current car
                        if (current_direction != cars_dir[car_process_idx]) begin
                            current_time <= current_time + t_pass;
                            current_direction <= cars_dir[car_process_idx];
                        end
                        if (current_time - cars_arrival[car_process_idx] > cars_irritation[car_process_idx]) begin
                            irritated_count <= irritated_count + 1;
                        end
                        current_time <= current_time + 3;
                        car_process_idx <= car_process_idx + 1;
                    end
                end
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule