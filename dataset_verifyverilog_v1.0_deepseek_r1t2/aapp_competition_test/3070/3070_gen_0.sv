module train_compensation #(
    parameter MAX_N = 8,           // Maximum stations (1-8)
    parameter MAX_M = 64,          // Maximum trains (1-64)
    parameter TIME_WIDTH = 12,     // Time value width (0-4095)
    parameter STATION_WIDTH = 3,   // Station index width (0-7)
    parameter REFUND_DELAY = 1800  // Required delay for refund
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Configuration
    input wire [STATION_WIDTH:0] N,  // Number of stations
    input wire [STATION_WIDTH:0] M,  // Number of trains
    
    // Train data input (streaming)
    input wire [47:0] train_data,     // Packed: {station[STATION_WIDTH:0], S[TIME_WIDTH-1:0], T[TIME_WIDTH-1:0], L[TIME_WIDTH-1:0]}
    input wire train_valid,
    input wire train_last,
    
    // Output
    output reg [TIME_WIDTH-1:0] result,
    output reg result_valid,
    output reg impossible
);

// Internal storage
reg [STATION_WIDTH-1:0] train_stations [0:MAX_M-1];
reg [TIME_WIDTH-1:0] train_S_arr [0:MAX_M-1];
reg [TIME_WIDTH-1:0] train_T_arr [0:MAX_M-1];
reg [TIME_WIDTH-1:0] train_L_arr [0:MAX_M-1];
reg train_valid_arr [0:MAX_M-1];

// FSM states
localparam [2:0] IDLE     = 3'd0;
localparam [2:0] LOAD     = 3'd1;
localparam [2:0] COMPUTE  = 3'd2;
localparam [2:0] DONE     = 3'd3;

reg [2:0] state, next_state;

// Computation registers
reg [STATION_WIDTH:0] load_idx;
reg [STATION_WIDTH:0] candidate_idx;
reg [TIME_WIDTH-1:0] best_time;
reg best_found;

// Journey simulation registers
reg [STATION_WIDTH:0] sim_station;
reg [TIME_WIDTH-1:0] sim_time;
reg [TIME_WIDTH-1:0] sim_target_time;
reg sim_feasible;
reg [1:0] sim_phase;
localparam [1:0] SIM_IDLE     = 2'd0;
localparam [1:0] SIM_ON_TIME  = 2'd1;
localparam [1:0] SIM_ACTUAL   = 2'd2;

// Simulation results storage
reg [TIME_WIDTH-1:0] a_on_time;

// Inner simulation FSM
reg [2:0] sim_state;

integer i; // Loop variable

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        state <= IDLE;
        result_valid <= 1'b0;
        impossible <= 1'b0;
        load_idx <= {STATION_WIDTH+1{1'b0}};
        candidate_idx <= {STATION_WIDTH+1{1'b0}};
        best_time <= {TIME_WIDTH{1'b1}};
        best_found <= 1'b0;
        sim_phase <= SIM_IDLE;
        
        // Initialize array contents
        for (i = 0; i < MAX_M; i = i + 1) begin
            train_valid_arr[i] <= 1'b0;
            train_stations[i] <= {STATION_WIDTH{1'b0}};
            train_S_arr[i] <= {TIME_WIDTH{1'b0}};
            train_T_arr[i] <= {TIME_WIDTH{1'b0}};
            train_L_arr[i] <= {TIME_WIDTH{1'b0}};
        end
    end else begin
        case (state)
            IDLE: begin
                result_valid <= 1'b0;
                impossible <= 1'b0;
                
                if (start) begin
                    state <= LOAD;
                    load_idx <= {STATION_WIDTH+1{1'b0}};
                    // Clear train valid flags
                    for (i = 0; i < MAX_M; i = i + 1)
                        train_valid_arr[i] <= 1'b0;
                end
            end
            
            LOAD: begin
                if (train_valid && (load_idx < M)) begin
                    // Unpack train data (format: {station, S, T, L})
                    train_stations[load_idx] <= train_data[47:44];
                    train_S_arr[load_idx] <= train_data[43:32];
                    train_T_arr[load_idx] <= train_data[31:20];
                    train_L_arr[load_idx] <= train_data[19:8];
                    train_valid_arr[load_idx] <= 1'b1;
                    load_idx <= load_idx + 1;
                end
                
                if (train_last || (load_idx >= M)) begin
                    state <= COMPUTE;
                    candidate_idx <= {STATION_WIDTH+1{1'b0}};
                    best_time <= {TIME_WIDTH{1'b1}};
                    best_found <= 1'b0;
                end
            end
            
            COMPUTE: begin
                case (sim_phase)
                    SIM_IDLE: begin
                        if (candidate_idx < M) begin
                            // Only consider valid trains from station 0
                            if (train_valid_arr[candidate_idx] && 
                                (train_stations[candidate_idx] == {STATION_WIDTH{1'b0}})) 
                            begin
                                // Initialize on-time simulation
                                sim_phase <= SIM_ON_TIME;
                                sim_station <= 1;
                                sim_time <= train_S_arr[candidate_idx];
                                sim_feasible <= 1'b1;
                            end else begin
                                candidate_idx <= candidate_idx + 1;
                            end
                        end else begin
                            state <= DONE;
                        end
                    end
                    
                    SIM_ON_TIME: begin
                        if (sim_feasible && (sim_station < N)) begin
                            // Find next train (on-time - no delays)
                            reg found;
                            reg [TIME_WIDTH-1:0] arrival_time;
                            found = 1'b0;
                            for (i = 0; i < MAX_M; i = i + 1) begin
                                if (train_valid_arr[i] && (train_stations[i] == sim_station) && 
                                   (train_S_arr[i] >= sim_time)) 
                                begin
                                    if (!found || (train_T_arr[i] < arrival_time)) begin
                                        found = 1'b1;
                                        arrival_time = train_T_arr[i];
                                    end
                                end
                            end
                            
                            if (found) begin
                                sim_time <= arrival_time;
                                sim_station <= sim_station + 1;
                            end else begin
                                sim_feasible <= 1'b0;
                            end
                        end else if (sim_station >= N) begin
                            // On-time path completed
                            a_on_time <= sim_time;
                            // Start actual simulation
                            sim_phase <= SIM_ACTUAL;
                            sim_station <= 1;
                            sim_time <= train_S_arr[candidate_idx];
                            sim_feasible <= 1'b1;
                        end else begin
                            // On-time path failed - invalid candidate
                            sim_phase <= SIM_IDLE;
                            candidate_idx <= candidate_idx + 1;
                        end
                    end
                    
                    SIM_ACTUAL: begin
                        if (sim_feasible && (sim_station < N)) begin
                            // Find next train (actual - includes delays)
                            reg found;
                            reg [TIME_WIDTH-1:0] min_departure;
                            found = 1'b0;
                            for (i = 0; i < MAX_M; i = i + 1) begin
                                if (train_valid_arr[i] && (train_stations[i] == sim_station) && 
                                   ((train_S_arr[i] + train_L_arr[i]) >= sim_time)) 
                                begin
                                    if (!found || ((train_S_arr[i] + train_L_arr[i]) < min_departure)) {
                                        found = 1'b1;
                                        min_departure = train_S_arr[i] + train_L_arr[i];
                                    }
                                end
                            end
                            
                            if (found) begin
                                sim_time <= min_departure;
                                sim_station <= sim_station + 1;
                            end else begin
                                sim_feasible <= 1'b0;
                            end
                        end else begin
                            // Actual path completed
                            if (sim_feasible && (sim_station >= N)) begin
                                // Check refund condition
                                if ((sim_time - a_on_time) >= REFUND_DELAY) begin
                                    if (train_S_arr[candidate_idx] < best_time) begin
                                        best_time <= train_S_arr[candidate_idx];
                                        best_found <= 1'b1;
                                    end
                                end
                            end else begin
                                // Actual path not feasible - always valid for refund
                                if (train_S_arr[candidate_idx] < best_time) begin
                                    best_time <= train_S_arr[candidate_idx];
                                    best_found <= 1'b1;
                                end
                            end
                            
                            // Process next candidate
                            sim_phase <= SIM_IDLE;
                            candidate_idx <= candidate_idx + 1;
                        end
                    end
                endcase
            end
            
            DONE: begin
                result_valid <= 1'b1;
                if (!best_found)
                    impossible <= 1'b1;
                
                if (!start)
                    state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule