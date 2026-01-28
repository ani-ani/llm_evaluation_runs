module BridgePokerCommittee(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] N,
    input wire [15:0] boat_time_in,
    input wire load_en,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [4:0] boat_count;
    reg [4:0] i_reg, j_reg;
    reg [15:0] arrival_time [0:31];
    reg [15:0] dp [0:32];
    reg [15:0] current_time;
    reg [15:0] min_time;
    reg [15:0] temp_time;
    reg [15:0] start_lowering;
    reg [15:0] wait_time;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            boat_count <= 5'd0;
            i_reg <= 5'd0;
            j_reg <= 5'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize arrival times
            integer k;
            for (k = 0; k < 32; k = k + 1) begin
                arrival_time[k] <= 16'd0;
            end
            
            // Initialize DP array
            for (k = 0; k < 32; k = k + 1) begin
                dp[k] <= 16'd0;
            end
            dp[32] <= 16'd0;
            
            current_time <= 16'd0;
            min_time <= 16'd0;
            temp_time <= 16'd0;
            start_lowering <= 16'd0;
            wait_time <= 16'd0;
        end else begin
            state <= next_state;
        end
    end

    // Load boat arrival times
    always @(posedge clk) begin
        if (state == LOAD && load_en && boat_count < N) begin
            arrival_time[boat_count] <= boat_time_in;
            boat_count <= boat_count + 5'd1;
        end
    end

    // Main FSM logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_count <= 8'd0;
                if (start && N > 5'd0) begin
                    next_state = LOAD;
                end
            end

            LOAD: begin
                if (boat_count == N) begin
                    next_state = COMPUTE;
                end
            end

            COMPUTE: begin
                cycle_count <= cycle_count + 8'd1;
                
                // Iterate through boats
                if (i_reg < N) begin
                    if (j_reg < N) begin
                        // Calculate start lowering time for boats i to j
                        start_lowering = arrival_time[i_reg] + 16'd60;
                        wait_time = start_lowering - arrival_time[j_reg];
                        
                        // Check if wait time is within limit
                        if (wait_time <= 16'd1800) begin
                            // Calculate total time for this segment
                            temp_time = start_lowering + 16'd20 + 16'd60;
                            
                            // Update DP array
                            if (temp_time + dp[j_reg + 5'd1] < dp[i_reg]) begin
                                dp[i_reg] <= temp_time + dp[j_reg + 5'd1];
                            end
                        end
                        
                        j_reg <= j_reg + 5'd1;
                    end else begin
                        j_reg <= i_reg;
                        i_reg <= i_reg + 5'd1;
                    end
                end else begin
                    // Find minimum time in DP array
                    min_time = dp[0];
                    integer k;
                    for (k = 1; k < N; k = k + 1) begin
                        if (dp[k] < min_time) begin
                            min_time = dp[k];
                        end
                    end
                    
                    result <= min_time;
                    next_state = FINISH;
                end
                
                // Safety check for infinite loops
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end
            end

            FINISH: begin
                done <= 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule