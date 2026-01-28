module DynamicProgrammingModule(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [7:0] Query_T,
    input [15:0] a_0, input [15:0] a_1, input [15:0] a_2, input [15:0] a_3,
    input [15:0] a_4, input [15:0] a_5, input [15:0] a_6, input [15:0] a_7,
    input [15:0] b_0, input [15:0] b_1, input [15:0] b_2, input [15:0] b_3,
    input [15:0] b_4, input [15:0] b_5, input [15:0] b_6, input [15:0] b_7,
    input [7:0] t_0, input [7:0] t_1, input [7:0] t_2, input [7:0] t_3,
    input [7:0] t_4, input [7:0] t_5, input [7:0] t_6, input [7:0] t_7,
    input [2:0] Query_Index,
    output reg [15:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PRECOMPUTE = 3'd1;
    localparam [2:0] DP_INIT = 3'd2;
    localparam [2:0] DP_UPDATE = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Precomputed fun values for each coaster and ride count (1-8)
    reg signed [15:0] fun_ride [0:7][0:7];
    
    // DP array
    reg signed [15:0] dp [0:255];
    
    // Counters and control signals
    reg [7:0] time_counter;
    reg [2:0] coaster_counter;
    reg [2:0] ride_counter;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;
    
    // Intermediate calculations
    reg signed [15:0] current_fun;
    reg signed [15:0] temp_dp;
    reg [7:0] time_minus_k_t;
    reg [7:0] k_t_i;
    
    // Precompute fun values for all coasters and ride counts
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            busy <= 1'b0;
            
            // Initialize all registers
            integer i, j;
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    fun_ride[i][j] <= 16'd0;
                end
            end
            
            for (i = 0; i < 256; i = i + 1) begin
                dp[i] <= 16'd0;
            end
            
            time_counter <= 8'd0;
            coaster_counter <= 3'd0;
            ride_counter <= 3'd0;
            cycle_count <= 8'd0;
            current_fun <= 16'd0;
            temp_dp <= 16'd0;
            time_minus_k_t <= 8'd0;
            k_t_i <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= PRECOMPUTE;
                        busy <= 1'b1;
                        coaster_counter <= 3'd0;
                        ride_counter <= 3'd0;
                        cycle_count <= 8'd0;
                    end
                end
                
                PRECOMPUTE: begin
                    // Precompute fun values for current coaster and ride count
                    case (coaster_counter)
                        3'd0: current_fun <= a_0 - (ride_counter * ride_counter) * b_0;
                        3'd1: current_fun <= a_1 - (ride_counter * ride_counter) * b_1;
                        3'd2: current_fun <= a_2 - (ride_counter * ride_counter) * b_2;
                        3'd3: current_fun <= a_3 - (ride_counter * ride_counter) * b_3;
                        3'd4: current_fun <= a_4 - (ride_counter * ride_counter) * b_4;
                        3'd5: current_fun <= a_5 - (ride_counter * ride_counter) * b_5;
                        3'd6: current_fun <= a_6 - (ride_counter * ride_counter) * b_6;
                        3'd7: current_fun <= a_7 - (ride_counter * ride_counter) * b_7;
                        default: current_fun <= 16'd0;
                    endcase
                    
                    fun_ride[coaster_counter][ride_counter] <= current_fun;
                    
                    // Move to next ride count
                    if (ride_counter < 7) begin
                        ride_counter <= ride_counter + 1'b1;
                    end else begin
                        ride_counter <= 3'd0;
                        if (coaster_counter < N - 1) begin
                            coaster_counter <= coaster_counter + 1'b1;
                        end else begin
                            coaster_counter <= 3'd0;
                            next_state <= DP_INIT;
                            time_counter <= 8'd0;
                        end
                    end
                    
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end
                
                DP_INIT: begin
                    // Initialize DP array
                    if (time_counter == 8'd0) begin
                        dp[0] <= 16'd0;
                    end else begin
                        dp[time_counter] <= 16'd0;
                    end
                    
                    if (time_counter < Query_T) begin
                        time_counter <= time_counter + 8'd1;
                    end else begin
                        time_counter <= 8'd0;
                        coaster_counter <= 3'd0;
                        ride_counter <= 3'd0;
                        next_state <= DP_UPDATE;
                    end
                    
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end
                
                DP_UPDATE: begin
                    // Get current coaster's ride time
                    case (coaster_counter)
                        3'd0: k_t_i <= t_0 * (ride_counter + 1'b1);
                        3'd1: k_t_i <= t_1 * (ride_counter + 1'b1);
                        3'd2: k_t_i <= t_2 * (ride_counter + 1'b1);
                        3'd3: k_t_i <= t_3 * (ride_counter + 1'b1);
                        3'd4: k_t_i <= t_4 * (ride_counter + 1'b1);
                        3'd5: k_t_i <= t_5 * (ride_counter + 1'b1);
                        3'd6: k_t_i <= t_6 * (ride_counter + 1'b1);
                        3'd7: k_t_i <= t_7 * (ride_counter + 1'b1);
                        default: k_t_i <= 8'd0;
                    endcase
                    
                    // Check if we can take this ride
                    if (time_counter >= k_t_i && fun_ride[coaster_counter][ride_counter] > 16'd0) begin
                        time_minus_k_t <= time_counter - k_t_i;
                        temp_dp <= dp[time_minus_k_t] + (ride_counter + 1'b1) * fun_ride[coaster_counter][ride_counter];
                        
                        if (temp_dp > dp[time_counter]) begin
                            dp[time_counter] <= temp_dp;
                        end
                    end
                    
                    // Move to next state
                    if (ride_counter < 7) begin
                        ride_counter <= ride_counter + 1'b1;
                    end else begin
                        ride_counter <= 3'd0;
                        if (coaster_counter < N - 1) begin
                            coaster_counter <= coaster_counter + 1'b1;
                        end else begin
                            coaster_counter <= 3'd0;
                            if (time_counter < Query_T) begin
                                time_counter <= time_counter + 8'd1;
                            end else begin
                                time_counter <= 8'd0;
                                next_state <= OUTPUT;
                            end
                        end
                    end
                    
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end
                
                OUTPUT: begin
                    result <= dp[Query_T];
                    done <= 1'b1;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule