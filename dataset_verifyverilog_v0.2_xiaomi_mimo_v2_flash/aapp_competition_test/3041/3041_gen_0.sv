module ticket_optimizer #(
    parameter N = 8
)(
    input clk,
    input rst_n,
    input start,
    input [2:0] trip_zone,
    input [7:0] trip_time,
    input load_trip,
    input compute,
    output reg [15:0] min_cost,
    output reg done,
    output reg [2:0] debug_state
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam LOAD_TRIP = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam COMPLETE = 3'b011;

    // Internal Registers
    reg [15:0] trips [0:N-1]; // Trip storage: {zone[2:0], time[7:0], unused[5:0]}
    reg [3:0] trip_load_idx;
    reg [3:0] trip_proc_idx;
    
    // DP State Storage: 64 states (A,B)
    reg [15:0] dp_cost [0:63];
    reg dp_valid [0:63];
    
    reg [2:0] state;
    
    // Combinational Wires
    wire [15:0] min_prev_wire;
    wire [15:0] next_dp_cost_wire [0:63];
    wire next_dp_valid_wire [0:63];
    wire [15:0] min_next_cost_wire;
    
    // Helper variables for combinational loops
    integer i, k, m;
    reg [2:0] A, B;
    reg [2:0] Z;

    // 1. Combinational Logic: Find minimum cost of previous state (for buying new ticket)
    always @(*) begin
        if (trip_proc_idx == 0) begin
            // Base case: No previous trips, base cost is 0
            min_prev_wire = 0;
        end else begin
            min_prev_wire = 16'hFFFF;
            for (k = 0; k < 64; k = k + 1) begin
                if (dp_valid[k] && dp_cost[k] < min_prev_wire) begin
                    min_prev_wire = dp_cost[k];
                end
            end
        end
    end

    // 2. Combinational Logic: Calculate next DP state based on current trip
    always @(*) begin
        // Get current trip zone
        Z = trips[trip_proc_idx][15:8];
        
        for (i = 0; i < 64; i = i + 1) begin
            A = i[5:3];
            B = i[2:0];
            
            // Default values
            next_dp_cost_wire[i] = 16'hFFFF;
            next_dp_valid_wire[i] = 0;
            
            // We only consider states where A <= B to avoid redundancy and invalid intervals
            if (A <= B) begin
                // Option 1: Reuse existing ticket
                if (dp_valid[i] && (Z >= A && Z <= B)) begin
                    next_dp_cost_wire[i] = dp_cost[i];
                    next_dp_valid_wire[i] = 1;
                end
                
                // Option 2: Buy new ticket covering this zone
                if (Z >= A && Z <= B) begin
                    // Cost of new ticket: 2 + (B - A)
                    // Plus the best cost accumulated so far
                    reg [15:0] buy_cost;
                    buy_cost = min_prev_wire + 2 + (B - A);
                    
                    // If buying is cheaper than reusing (or if we didn't have a valid ticket)
                    if (buy_cost < next_dp_cost_wire[i]) begin
                        next_dp_cost_wire[i] = buy_cost;
                        next_dp_valid_wire[i] = 1;
                    end
                end
            end
        end
    end

    // 3. Combinational Logic: Find minimum cost for output
    always @(*) begin
        min_next_cost_wire = 16'hFFFF;
        for (m = 0; m < 64; m = m + 1) begin
            if (next_dp_valid_wire[m] && next_dp_cost_wire[m] < min_next_cost_wire) begin
                min_next_cost_wire = next_dp_cost_wire[m];
            end
        end
    end

    // 4. Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            trip_load_idx <= 0;
            trip_proc_idx <= 0;
            done <= 0;
            min_cost <= 0;
            debug_state <= 0;
            // Reset DP valid flags
            for (i = 0; i < 64; i = i + 1) begin
                dp_valid[i] <= 0;
            end
        end else begin
            debug_state <= state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        trip_load_idx <= 0;
                        trip_proc_idx <= 0;
                        done <= 0;
                        min_cost <= 0;
                        state <= LOAD_TRIP;
                    end
                end

                LOAD_TRIP: begin
                    if (load_trip) begin
                        trips[trip_load_idx] <= {trip_zone, trip_time, 5'b0};
                        trip_load_idx <= trip_load_idx + 1;
                        if (trip_load_idx == N - 1) begin
                            state <= COMPUTE;
                        end
                    end
                end

                COMPUTE: begin
                    if (compute) begin
                        // Update DP State with calculated next state
                        for (i = 0; i < 64; i = i + 1) begin
                            dp_cost[i] <= next_dp_cost_wire[i];
                            dp_valid[i] <= next_dp_valid_wire[i];
                        end
                        
                        // Update output cost
                        min_cost <= min_next_cost_wire;
                        
                        // Move to next trip
                        trip_proc_idx <= trip_proc_idx + 1;
                        
                        // Check if all trips processed
                        if (trip_proc_idx == N - 1) begin
                            state <= COMPLETE;
                            done <= 1;
                        end
                    end
                end

                COMPLETE: begin
                    // Operation complete, wait for reset or start
                end
            endcase
        end
    end

endmodule