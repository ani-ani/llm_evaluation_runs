module train_compensation #(
    parameter MAX_N = 8,
    parameter MAX_M = 64,
    parameter TIME_WIDTH = 12,
    parameter STATION_WIDTH = 3,
    parameter REFUND_DELAY = 1800
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [STATION_WIDTH:0] N,
    input wire [STATION_WIDTH:0] M,
    input wire [47:0] train_data,
    input wire train_valid,
    input wire train_last,
    output reg [TIME_WIDTH-1:0] result,
    output reg result_valid,
    output reg impossible
);

reg [STATION_WIDTH-1:0] train_stations [0:MAX_M-1];
reg [TIME_WIDTH-1:0] train_S_arr [0:MAX_M-1];
reg [TIME_WIDTH-1:0] train_T_arr [0:MAX_M-1];
reg [TIME_WIDTH-1:0] train_L_arr [0:MAX_M-1];
reg train_valid_arr [0:MAX_M-1];

reg [2:0] state;
localparam [2:0] IDLE = 3'd0;
localparam [2:0] LOAD = 3'd1;
localparam [2:0] COMPUTE = 3'd2;
localparam [2:0] DONE = 3'd3;

reg [STATION_WIDTH:0] load_idx;
reg [STATION_WIDTH:0] candidate_idx;
reg [TIME_WIDTH-1:0] best_time;
reg best_found;

reg [STATION_WIDTH:0] sim_station;
reg [TIME_WIDTH-1:0] sim_time;
reg sim_feasible;
reg [1:0] sim_state;
reg [TIME_WIDTH-1:0] a_on;

integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result_valid <= 1'b0;
        impossible <= 1'b0;
        load_idx <= 0;
        candidate_idx <= 0;
        best_time <= {TIME_WIDTH{1'b1}};
        best_found <= 1'b0;
        for (i = 0; i < MAX_M; i = i + 1) begin
            train_valid_arr[i] <= 1'b0;
        end
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= LOAD;
                    load_idx <= 0;
                    result_valid <= 1'b0;
                end
            end
            
            LOAD: begin
                if (train_valid && load_idx < M) begin
                    train_stations[load_idx] <= train_data[47:44];
                    train_S_arr[load_idx] <= train_data[43:32];
                    train_T_arr[load_idx] <= train_data[31:20];
                    train_L_arr[load_idx] <= train_data[19:8];
                    train_valid_arr[load_idx] <= 1'b1;
                    load_idx <= load_idx + 1;
                end else if (train_last || load_idx >= M) begin
                    state <= COMPUTE;
                    candidate_idx <= 0;
                    best_time <= {TIME_WIDTH{1'b1}};
                    best_found <= 1'b0;
                end
            end
            
            COMPUTE: begin
                if (candidate_idx < M) begin
                    if (train_valid_arr[candidate_idx] && train_stations[candidate_idx] == 0) begin
                        sim_station <= 1;
                        sim_time <= train_S_arr[candidate_idx];
                        sim_feasible <= 1'b1;
                        sim_state <= 2'd0;
                        a_on <= 0;
                    end else begin
                        candidate_idx <= candidate_idx + 1;
                    end
                end else begin
                    state <= DONE;
                    if (best_found) begin
                        result <= best_time;
                        result_valid <= 1'b1;
                        impossible <= 1'b0;
                    end else begin
                        result <= 0;
                        result_valid <= 1'b1;
                        impossible <= 1'b1;
                    end
                end
            end
            
            DONE: begin
                if (!start) begin
                    state <= IDLE;
                    result_valid <= 1'b0;
                end
            end
            
            default: state <= IDLE;
        endcase
        
        if (state == COMPUTE && sim_state < 2'd2) begin
            if (sim_station < N && sim_feasible) begin
                if (sim_state == 2'd0) begin
                    reg found;
                    reg [TIME_WIDTH-1:0] arrival;
                    found = 1'b0;
                    arrival = 0;
                    for (i = 0; i < MAX_M; i = i + 1) begin
                        if (train_valid_arr[i] && train_stations[i] == sim_station) begin
                            if (train_S_arr[i] >= sim_time) begin
                                arrival = train_T_arr[i];
                                found = 1'b1;
                            end
                        end
                    end
                    if (found) begin
                        sim_time <= arrival;
                        sim_station <= sim_station + 1;
                    end else begin
                        sim_feasible <= 1'b0;
                    end
                end else begin
                    reg found;
                    reg [TIME_WIDTH-1:0] arrival;
                    found = 1'b0;
                    arrival = 0;
                    for (i = 0; i < MAX_M; i = i + 1) begin
                        if (train_valid_arr[i] && train_stations[i] == sim_station) begin
                            if (train_S_arr[i] + train_L_arr[i] >= sim_time) begin
                                arrival = train_T_arr[i] + train_L_arr[i];
                                found = 1'b1;
                            end
                        end
                    end
                    if (found) begin
                        sim_time <= arrival;
                        sim_station <= sim_station + 1;
                    end else begin
                        sim_feasible <= 1'b0;
                    end
                end
            end else begin
                if (sim_state == 2'd0) begin
                    if (sim_feasible) begin
                        a_on <= sim_time;
                        sim_state <= 2'd1;
                        sim_station <= 1;
                        sim_time <= train_S_arr[candidate_idx];
                        sim_feasible <= 1'b1;
                    end else begin
                        candidate_idx <= candidate_idx + 1;
                        sim_state <= 2'd2;
                    end
                end else begin
                    if (sim_feasible) begin
                        if (sim_time - a_on >= REFUND_DELAY) begin
                            if (train_S_arr[candidate_idx] < best_time) begin
                                best_time <= train_S_arr[candidate_idx];
                                best_found <= 1'b1;
                            end
                        end
                    end else begin
                        if (train_S_arr[candidate_idx] < best_time) begin
                            best_time <= train_S_arr[candidate_idx];
                            best_found <= 1'b1;
                        end
                    end
                    candidate_idx <= candidate_idx + 1;
                    sim_state <= 2'd2;
                end
            end
        end
    end
end

endmodule