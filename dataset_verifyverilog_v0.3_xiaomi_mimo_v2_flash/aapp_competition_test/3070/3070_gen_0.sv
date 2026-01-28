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
    input wire [47:0] train_data,    // Packed: {station[3:0], S[11:0], T[11:0], L[11:0]}
    input wire train_valid,
    input wire train_last,
    
    // Output
    output reg [TIME_WIDTH-1:0] result,
    output reg result_valid,
    output reg impossible
);

// Internal storage for trains
reg [STATION_WIDTH-1:0] train_stations [0:MAX_M-1];
reg [TIME_WIDTH-1:0] train_S_arr [0:MAX_M-1];
reg [TIME_WIDTH-1:0] train_T_arr [0:MAX_M-1];
reg [TIME_WIDTH-1:0] train_L_arr [0:MAX_M-1];
reg train_valid_arr [0:MAX_M-1];

// State machine
reg [2:0] state;
localparam [2:0] IDLE = 3'd0;
localparam [2:0] LOAD = 3'd1;
localparam [2:0] COMPUTE = 3'd2;
localparam [2:0] DONE = 3'd3;

// Computation registers
reg [STATION_WIDTH:0] load_idx;
reg [STATION_WIDTH:0] candidate_idx;
reg [TIME_WIDTH-1:0] best_time;
reg best_found;

// Journey simulation state
reg [STATION_WIDTH:0] sim_station;
reg [TIME_WIDTH-1:0] sim_time;
reg sim_feasible;
reg [1:0] sim_state;  // 0=on-time, 1=actual, 2=done
reg [STATION_WIDTH-1:0] sim_train_idx;
reg [TIME_WIDTH-1:0] a_on_time;

// Cycle counter for safety
reg [15:0] cycle_count;
localparam [15:0] MAX_CYCLES = 16'd10000;

// Helper signals for find next train
reg found_train;
reg [TIME_WIDTH-1:0] arrival_time;

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result_valid <= 1'b0;
        impossible <= 1'b0;
        load_idx <= {STATION_WIDTH+1{1'b0}};
        candidate_idx <= {STATION_WIDTH+1{1'b0}};
        best_time <= {TIME_WIDTH{1'b1}};
        best_found <= 1'b0;
        cycle_count <= 16'd0;
        // Initialize all valid flags
        for (integer i = 0; i < MAX_M; i = i + 1) begin
            train_valid_arr[i] <= 1'b0;
        end
        // Initialize simulation state
        sim_station <= {STATION_WIDTH+1{1'b0}};
        sim_time <= {TIME_WIDTH{1'b0}};
        sim_feasible <= 1'b0;
        sim_state <= 2'd2;
        sim_train_idx <= {STATION_WIDTH{1'b0}};
        a_on_time <= {TIME_WIDTH{1'b0}};
    end else begin
        cycle_count <= cycle_count + 16'd1;
        
        case (state)
            IDLE: begin
                result_valid <= 1'b0;
                impossible <= 1'b0;
                cycle_count <= 16'd0;
                if (start) begin
                    state <= LOAD;
                    load_idx <= {STATION_WIDTH+1{1'b0}};
                    candidate_idx <= {STATION_WIDTH+1{1'b0}};
                    best_time <= {TIME_WIDTH{1'b1}};
                    best_found <= 1'b0;
                    // Clear all valid flags
                    for (integer i = 0; i < MAX_M; i = i + 1) begin
                        train_valid_arr[i] <= 1'b0;
                    end
                end
            end
            
            LOAD: begin
                if (train_valid && load_idx < M) begin
                    // Extract from packed data
                    train_stations[load_idx] <= train_data[47:44];
                    train_S_arr[load_idx] <= train_data[43:32];
                    train_T_arr[load_idx] <= train_data[31:20];
                    train_L_arr[load_idx] <= train_data[19:8];
                    train_valid_arr[load_idx] <= 1'b1;
                    load_idx <= load_idx + {STATION_WIDTH+1{1'b0}} + {{STATION_WIDTH{1'b0}}, 1'b1};
                end else if (train_last || load_idx >= M) begin
                    state <= COMPUTE;
                    candidate_idx <= {STATION_WIDTH+1{1'b0}};
                    best_time <= {TIME_WIDTH{1'b1}};
                    best_found <= 1'b0;
                    sim_state <= 2'd2;
                end
            end
            
            COMPUTE: begin
                if (cycle_count >= MAX_CYCLES) begin
                    // Timeout safety
                    state <= DONE;
                    result <= 16'd0;
                    result_valid <= 1'b1;
                    impossible <= 1'b1;
                end else if (candidate_idx < M) begin
                    // Check if from station 0 (index 0)
                    if (train_valid_arr[candidate_idx] && train_stations[candidate_idx] == {STATION_WIDTH{1'b0}}) begin
                        // Initialize on-time simulation
                        sim_station <= {{STATION_WIDTH{1'b0}}, 1'b1};  // station 1
                        sim_time <= train_S_arr[candidate_idx];
                        sim_feasible <= 1'b1;
                        sim_state <= 2'd0;  // on-time
                        sim_train_idx <= {STATION_WIDTH{1'b0}};
                    end else begin
                        candidate_idx <= candidate_idx + {STATION_WIDTH+1{1'b0}} + {{STATION_WIDTH{1'b0}}, 1'b1};
                    end
                end else begin
                    state <= DONE;
                    if (best_found) begin
                        result <= best_time;
                        result_valid <= 1'b1;
                        impossible <= 1'b0;
                    end else begin
                        result <= {TIME_WIDTH{1'b0}};
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
        
        // Journey simulation logic (when in COMPUTE and sim_state active)
        if (state == COMPUTE && sim_state < 2'd2 && cycle_count < MAX_CYCLES) begin
            if (sim_station < N && sim_feasible) begin
                // Find next train logic
                found_train <= 1'b0;
                arrival_time <= {TIME_WIDTH{1'b0}};
                
                // Sequential search through trains
                if (sim_train_idx < M) begin
                    if (train_valid_arr[sim_train_idx] && train_stations[sim_train_idx] == sim_station) begin
                        if (sim_state == 2'd0) begin  // on-time
                            if (train_S_arr[sim_train_idx] >= sim_time) begin
                                arrival_time <= train_T_arr[sim_train_idx];
                                found_train <= 1'b1;
                            end
                        end else begin  // actual
                            if (train_S_arr[sim_train_idx] + train_L_arr[sim_train_idx] >= sim_time) begin
                                arrival_time <= train_T_arr[sim_train_idx] + train_L_arr[sim_train_idx];
                                found_train <= 1'b1;
                            end
                        end
                    end
                    sim_train_idx <= sim_train_idx + {STATION_WIDTH{1'b0}} + {{STATION_WIDTH-1{1'b0}}, 1'b1};
                end
                
                // After search completes or train found
                if (sim_train_idx >= M - 16'd1 || found_train) begin
                    if (found_train) begin
                        sim_time <= arrival_time;
                        sim_station <= sim_station + {STATION_WIDTH{1'b0}} + {{STATION_WIDTH-1{1'b0}}, 1'b1};
                        sim_train_idx <= {STATION_WIDTH{1'b0}};  // Reset for next station
                    end else begin
                        sim_feasible <= 1'b0;
                        sim_train_idx <= {STATION_WIDTH{1'b0}};
                    end
                end
            end else begin
                // Simulation complete for this state
                if (sim_state == 2'd0) begin  // on-time complete
                    if (sim_feasible) begin
                        a_on_time <= sim_time;  // Store A_on
                        sim_state <= 2'd1;      // Start actual
                        sim_station <= {{STATION_WIDTH{1'b0}}, 1'b1};  // station 1
                        sim_time <= train_S_arr[candidate_idx];  // Start at S of candidate
                        sim_feasible <= 1'b1;
                        sim_train_idx <= {STATION_WIDTH{1'b0}};
                    end else begin
                        sim_state <= 2'd2;
                        candidate_idx <= candidate_idx + {STATION_WIDTH+1{1'b0}} + {{STATION_WIDTH{1'b0}}, 1'b1};
                    end
                end else begin  // actual complete
                    if (sim_feasible) begin
                        // Both feasible, check refund condition
                        if (sim_time >= a_on_time + REFUND_DELAY) begin
                            // Refund condition met
                            if (train_S_arr[candidate_idx] < best_time) begin
                                best_time <= train_S_arr[candidate_idx];
                                best_found <= 1'b1;
                            end
                        end
                    end else begin
                        // Actual not feasible - always satisfies condition
                        if (train_S_arr[candidate_idx] < best_time) begin
                            best_time <= train_S_arr[candidate_idx];
                            best_found <= 1'b1;
                        end
                    end
                    sim_state <= 2'd2;
                    candidate_idx <= candidate_idx + {STATION_WIDTH+1{1'b0}} + {{STATION_WIDTH{1'b0}}, 1'b1};
                    sim_train_idx <= {STATION_WIDTH{1'b0}};
                end
            end
        end
    end
end

endmodule