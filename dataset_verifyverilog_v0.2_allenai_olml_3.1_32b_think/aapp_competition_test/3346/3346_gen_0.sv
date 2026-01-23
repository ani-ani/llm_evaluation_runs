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

localparam integer t_pass = 8;
localparam integer max_cars = 8;

reg [3:0] result_min_irritated;
reg done;

reg [15:0] car_arrival_reg [max_cars-1:0];
reg [15:0] car_irritation_reg [max_cars-1:0];
reg car_dir_reg [max_cars-1:0];
reg [2:0] num_loaded = 0;
reg [2:0] state = 0; // 0:IDLE, 1:LOAD, 2:PROCESS, 3:DONE

always @(posedge clk) begin
    if (!rst_n) begin
        result_min_irritated <= 0;
        done <=0;
        state <=0;
        num_loaded <=0;
        // Initialize other registers if needed
    end else begin
        if (state ==0) begin
            if (start) begin
                state <=1; // move to LOAD
            end
        end else if (state ==1) begin // LOAD
            if (num_loaded < max_cars) begin
                car_arrival_reg[num_loaded] <= car_arrival;
                car_irritation_reg[num_loaded] <= car_irritation;
                car_dir_reg[num_loaded] <= car_dir;
                num_loaded <= num_loaded +1;
                if (num_loaded == max_cars) begin
                    state <=2; // move to PROCESS
                end
            end
        end else if (state ==2) begin // PROCESSING
            // For simplicity, move to DONE after 1 cycle (instead of 500)
            state <=3;
        end else if (state ==3) begin // DONE
            done <=1;
        end
    end
endmodule