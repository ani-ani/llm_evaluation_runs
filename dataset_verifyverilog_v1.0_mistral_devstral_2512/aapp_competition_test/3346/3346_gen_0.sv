module TrafficOptimizer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] t,          // Segment pass time (4-180)
    input wire [3:0] n,          // Number of cars (1-8)
    input wire [7:0] car_direction, // 1-bit per car: 1=W, 0=E
    input wire [135:0] car_arrival, // 17-bit per car (8 cars)
    input wire [95:0] car_irritation, // 12-bit per car (8 cars)
    output reg [3:0] result,
    output reg done
);

// State encoding
localparam [2:0] IDLE = 3'd0;
localparam [2:0] PREPARE = 3'd1;
localparam [2:0] DP_LOOP = 3'd2;
localparam [2:0] UPDATE_STATE = 3'd3;
localparam [2:0] FIND_MIN = 3'd4;
localparam [2:0] FINISHED = 3'd5;

// DP memory: 9x9x3 = 243 entries
// Each entry: {valid, irritation[3:0], time[15:0]}
reg [20:0] dp [0:242];

// Working registers
reg [2:0] state;
reg [3:0] i, j;           // Processed car counts
reg [1:0] d;              // Last direction: 0=W, 1=E, 2=none
reg [3:0] west_count, east_count;
reg [15:0] west_arrival [0:7];
reg [11:0] west_irritation [0:7];
reg [15:0] east_arrival [0:7];
reg [11:0] east_irritation [0:7];
reg [15:0] current_time;
reg [3:0] current_irr;
reg [15:0] best_time;
reg [3:0] best_irr;
reg [3:0] temp_irr;
reg [15:0] temp_time;
reg [15:0] car_arrival_temp;
reg [11:0] car_irritation_temp;
reg [15:0] release_time;
reg [15:0] waiting;
reg irritation_flag;
reg [2:0] loop_d;

// Helper: index calculation
function [8:0] state_index;
    input [3:0] i_val;
    input [3:0] j_val;
    input [1:0] d_val;
    begin
        state_index = {i_val, j_val, d_val};
    end
endfunction

integer idx;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 4'd0;
        // Reset DP memory
        for (idx = 0; idx < 243; idx = idx + 1) begin
            dp[idx] <= 21'b0; // All invalid
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= PREPARE;
                    i <= 4'd0;
                    j <= 4'd0;
                    d <= 2'd0;
                    west_count <= 4'd0;
                    east_count <= 4'd0;
                end
            end
            
            PREPARE: begin
                // Separate cars into west and east lists
                if (i < n) begin
                    if (car_direction[i]) begin
                        west_arrival[west_count] <= car_arrival[17*i +: 17];
                        west_irritation[west_count] <= car_irritation[12*i +: 12];
                        west_count <= west_count + 4'd1;
                    end else begin
                        east_arrival[east_count] <= car_arrival[17*i +: 17];
                        east_irritation[east_count] <= car_irritation[12*i +: 12];
                        east_count <= east_count + 4'd1;
                    end
                    i <= i + 4'd1;
                end else begin
                    // Initialize DP memory
                    for (idx = 0; idx < 243; idx = idx + 1) begin
                        dp[idx] <= 21'b0;
                    end
                    // Set initial state (0,0,2) to valid with time=0, irr=0
                    dp[state_index(4'd0,4'd0,2'd2)] <= 21'b1_0000_000000000000;
                    i <= 4'd0;
                    j <= 4'd0;
                    d <= 2'd0;
                    state <= DP_LOOP;
                end
            end
            
            DP_LOOP: begin
                if (i <= west_count && j <= east_count && d < 3) begin
                    // Read current state
                    current_irr <= dp[state_index(i,j,d)][19:16];
                    current_time <= dp[state_index(i,j,d)][15:0];
                    if (dp[state_index(i,j,d)][20]) begin // Valid
                        state <= UPDATE_STATE;
                        loop_d <= 2'd0; // 0=west, 1=east
                    end else begin
                        // Invalid, go to next d
                        d <= d + 2'd1;
                        if (d == 2'd2) begin
                            if (j == east_count) begin
                                if (i == west_count) state <= FIND_MIN;
                                else begin i <= i + 4'd1; j <= 4'd0; d <= 2'd0; end
                            end else begin
                                j <= j + 4'd1;
                                d <= 2'd0;
                            end
                        end
                    end
                end else if (i > west_count || j > east_count) begin
                    state <= FIND_MIN;
                end else begin
                    state <= FIND_MIN;
                end
            end
            
            UPDATE_STATE: begin
                case (loop_d)
                    2'd0: begin // Try west car
                        if (i < west_count) begin
                            car_arrival_temp <= west_arrival[i];
                            car_irritation_temp <= west_irritation[i];
                            // Calculate gap
                            if (d == 2'd0) temp_time <= current_time + 16'd3;
                            else if (d == 2'd1) temp_time <= current_time + t;
                            else temp_time <= current_time;
                            // Wait one cycle for multiplication? No, just use max
                            release_time <= (current_time + ((d == 2'd0) ? 16'd3 : (d == 2'd1) ? t : 16'd0)) > west_arrival[i] ? 
                                           (current_time + ((d == 2'd0) ? 16'd3 : (d == 2'd1) ? t : 16'd0)) : west_arrival[i];
                            waiting <= ((current_time + ((d == 2'd0) ? 16'd3 : (d == 2'd1) ? t : 16'd0)) > west_arrival[i] ? 
                                       (current_time + ((d == 2'd0) ? 16'd3 : (d == 2'd1) ? t : 16'd0)) : west_arrival[i]) - west_arrival[i];
                            loop_d <= 2'd1;
                        end else begin
                            loop_d <= 2'd1;
                        end
                    end
                    2'd1: begin // Process west result and try east
                        if (i < west_count) begin
                            irritation_flag <= (waiting > car_irritation_temp);
                            temp_irr <= current_irr + ((waiting > car_irritation_temp) ? 4'd1 : 4'd0);
                            // Update state (i+1, j, 0)
                            // We'll write this in next cycle
                        end
                        if (j < east_count) begin
                            car_arrival_temp <= east_arrival[j];
                            car_irritation_temp <= east_irritation[j];
                            release_time <= (current_time + ((d == 2'd1) ? 16'd3 : (d == 2'd0) ? t : 16'd0)) > east_arrival[j] ? 
                                           (current_time + ((d == 2'd1) ? 16'd3 : (d == 2'd0) ? t : 16'd0)) : east_arrival[j];
                            waiting <= ((current_time + ((d == 2'd1) ? 16'd3 : (d == 2'd0) ? t : 16'd0)) > east_arrival[j] ? 
                                       (current_time + ((d == 2'd1) ? 16'd3 : (d == 2'd0) ? t : 16'd0)) : east_arrival[j]) - east_arrival[j];
                            loop_d <= 2'd2;
                        end else begin
                            loop_d <= 2'd3;
                        end
                    end
                    2'd2: begin // Process east result
                        irritation_flag <= (waiting > car_irritation_temp);
                        // Write both updates (west and east) if valid
                        if (i < west_count) begin
                            // Write west update: state (i+1, j, 0)
                            dp[state_index(i+4'd1, j, 2'd0)] <= {1'b1, temp_irr, release_time};
                        end
                        if (j < east_count) begin
                            // Write east update: state (i, j+1, 1)
                            dp[state_index(i, j+4'd1, 2'd1)] <= {1'b1, temp_irr, release_time};
                        end
                        loop_d <= 2'd3;
                    end
                    2'd3: begin // Move to next state
                        d <= d + 2'd1;
                        if (d == 2'd2) begin
                            if (j == east_count) begin
                                if (i == west_count) state <= FIND_MIN;
                                else begin i <= i + 4'd1; j <= 4'd0; d <= 2'd0; end
                            end else begin
                                j <= j + 4'd1;
                                d <= 2'd0;
                            end
                        end else begin
                            state <= DP_LOOP;
                        end
                    end
                endcase
            end
            
            FIND_MIN: begin
                // Find minimum irritation among final states
                best_irr <= 4'd15; // Initialize to max
                i <= west_count;
                j <= east_count;
                d <= 2'd0;
                state <= FINISHED;
            end
            
            FINISHED: begin
                // For d=0,1,2, check dp[i][j][d] and take minimum
                if (d < 3) begin
                    if (dp[state_index(i,j,d)][20]) begin
                        if (dp[state_index(i,j,d)][19:16] < best_irr) begin
                            best_irr <= dp[state_index(i,j,d)][19:16];
                        end
                    end
                    d <= d + 2'd1;
                end else begin
                    result <= best_irr;
                    done <= 1'b1;
                    state <= IDLE;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule