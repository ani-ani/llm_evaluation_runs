module earliest_train(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [4:0] M,
    input [3:0] train_X [0:15],
    input [15:0] train_S [0:15],
    input [15:0] train_T [0:15],
    input [15:0] train_L [0:15],
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] CAPTURE     = 3'd1;
    localparam [2:0] INIT_STATION = 3'd2;
    localparam [2:0] PROCESS_TRAINS = 3'd3;
    localparam [2:0] UPDATE_RESULT = 3'd4;
    localparam [2:0] FINISH      = 3'd5;

    // Constants
    localparam [15:0] INF = 16'd65535;
    localparam [15:0] COMP_DELAY = 16'd1800;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] current_N;
    reg [4:0] current_M;
    reg [3:0] st_idx;
    reg [4:0] tr_idx;
    reg [15:0] min_arrival [0:3]; // Stores earliest arrival for stations 1-4
    reg [15:0] scheduled_arrival;
    reg [15:0] delayed_arrival;
    reg [15:0] arrival_diff;
    reg valid_path;
    reg [15:0] temp_min;
    reg [2:0] cycle_count; // Safety counter

    // Function to check condition
    function automatic [0:0] check_compensation;
        input [15:0] sched;
        input [15:0] delay;
        reg [15:0] act_arr;
        reg [15:0] diff;
        begin
            act_arr = sched + delay;
            diff = act_arr - sched;
            check_compensation = (diff >= COMP_DELAY);
        end
    endfunction

    // Combinational logic for next state and control signals
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = CAPTURE;
            end
            CAPTURE: begin
                next_state = INIT_STATION;
            end
            INIT_STATION: begin
                if (st_idx < current_N - 4'd1)
                    next_state = PROCESS_TRAINS;
                else
                    next_state = UPDATE_RESULT;
            end
            PROCESS_TRAINS: begin
                if (tr_idx < current_M - 5'd1)
                    next_state = PROCESS_TRAINS;
                else
                    next_state = INIT_STATION;
            end
            UPDATE_RESULT: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            current_N <= 4'd0;
            current_M <= 5'd0;
            st_idx <= 4'd0;
            tr_idx <= 5'd0;
            cycle_count <= 3'd0;
            min_arrival[0] <= 16'd0;
            min_arrival[1] <= 16'd0;
            min_arrival[2] <= 16'd0;
            min_arrival[3] <= 16'd0;
            valid_path <= 1'b0;
            temp_min <= 16'd0;
            scheduled_arrival <= 16'd0;
            delayed_arrival <= 16'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 3'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'd0;
                    cycle_count <= 3'd0;
                    if (start) begin
                        current_N <= N;
                        current_M <= M;
                    end
                end

                CAPTURE: begin
                    // Inputs are captured from ports directly in logic, 
                    // ensuring they are stable for the subsequent cycles.
                    // Initialize min_arrival array
                    min_arrival[0] <= 16'd0; // Station 1
                    if (current_N > 4'd1) min_arrival[1] <= INF;
                    if (current_N > 4'd2) min_arrival[2] <= INF;
                    if (current_N > 4'd3) min_arrival[3] <= INF;
                    st_idx <= 4'd1; // Start from station 1 (index 1)
                end

                INIT_STATION: begin
                    // Check if we processed all stations
                    if (st_idx >= current_N - 4'd1) begin
                        // Done with stations
                    end else begin
                        // Start processing trains for this station pair
                        tr_idx <= 5'd0;
                        valid_path <= 1'b0;
                        temp_min <= min_arrival[st_idx + 1]; // Initialize with current min
                    end
                end

                PROCESS_TRAINS: begin
                    // Check train logic
                    // Train goes from st_idx to st_idx+1?
                    if (train_X[tr_idx] == st_idx) begin
                        // Check if we can catch this train (min_arrival[st_idx] <= train_S[tr_idx])
                        if (min_arrival[st_idx] <= train_S[tr_idx]) begin
                            // Check compensation condition
                            // delayed_arrival - scheduled_arrival >= 1800
                            scheduled_arrival <= train_T[tr_idx];
                            delayed_arrival <= train_T[tr_idx] + train_L[tr_idx];
                            
                            // Perform check
                            if ((train_T[tr_idx] + train_L[tr_idx]) - train_T[tr_idx] >= COMP_DELAY) begin
                                // Update min arrival for next station
                                if (delayed_arrival < temp_min) begin
                                    temp_min <= delayed_arrival;
                                end
                                valid_path <= 1'b1;
                            end
                        end
                    end
                    
                    // If this was the last train, update the min_arrival array
                    if (tr_idx == current_M - 5'd1) begin
                        if (valid_path) begin
                            min_arrival[st_idx + 1] <= temp_min;
                        end
                    end
                end

                UPDATE_RESULT: begin
                    // Result is min_arrival for station N (index N-1)
                    // Station indices: 1->0, 2->1, 3->2, 4->3
                    result <= min_arrival[current_N - 4'd1];
                end

                FINISH: begin
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule