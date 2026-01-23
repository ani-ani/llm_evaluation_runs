module tram_scheduling(
    input clk,
    input rst_n,
    input start,
    input [7:0] s,
    input [7:0] num_stops,
    input [7:0] num_lines,
    input [7:0] t0 [0:7],
    input [7:0] p [0:7],
    input [7:0] d [0:7],
    input [2:0] u [0:7],
    input [2:0] v [0:7],
    output reg [7:0] latest_departure,
    output reg valid,
    output reg impossible
);

    // State definition
    reg [2:0] state;
    localparam IDLE = 3'd0;
    localparam INIT = 3'd1;
    localparam PROCESSING = 3'd2;
    localparam UPDATE = 3'd3;
    localparam DONE = 3'd4;

    // Latest arrival times array (index 0-7 for stops)
    reg [7:0] latest_arrival [0:7];
    reg [7:0] next_latest_arrival [0:7];

    // Temporary values for calculation
    reg [7:0] target_time;
    reg [7:0] dep_time;
    reg [7:0] arr_time;
    reg [7:0] diff;
    reg [7:0] k;

    // Iteration counters
    reg [2:0] iter_count; // Max 8 iterations
    reg [2:0] line_index; // Max 8 lines
    reg [2:0] stop_index; // Max 8 stops
    reg change_detected;

    // Helper logic for calculation (combinational)
    always @(*) begin
        // Default assignments
        dep_time = 8'd0;
        arr_time = 8'd0;
        diff = 8'd0;
        k = 8'd0;

        // Check if we can catch a tram from u to v (backwards: v -> u)
        // We are at stop v, want to arrive at u to possibly extend arrival time
        // Target arrival at u is latest_arrival[v] - d[i]
        // Latest departure from u is what we calculate
        
        // target_time is the latest allowed departure from u to arrive at v on time
        if (latest_arrival[v[line_index]] > d[line_index]) begin
            target_time = latest_arrival[v[line_index]] - d[line_index];
        end else begin
            target_time = 8'd0; // Cannot arrive at v in time to take this tram back
        end

        // Find latest departure t0 + k*p <= target_time
        if (target_time >= t0[line_index]) begin
            // k = floor((target_time - t0) / p)
            // Simple division for 8-bit values
            diff = target_time - t0[line_index];
            if (p[line_index] == 8'd0) begin
                // Period 0 means infinite frequency (or single trip, treat as single)
                // If diff >= 0, we can take the first trip (k=0)
                k = 8'd0;
            end else begin
                k = diff / p[line_index];
            end
            dep_time = t0[line_index] + (k * p[line_index]);
            arr_time = dep_time + d[line_index];
        end else begin
            // target_time < t0, cannot catch any tram
            dep_time = 8'd0;
            arr_time = 8'd0;
        end
    end

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            impossible <= 1'b0;
            latest_departure <= 8'd0;
            // Reset array not strictly needed but good practice
            for (i = 0; i < 8; i = i + 1) begin
                latest_arrival[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    impossible <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize latest_arrival
                    // Stop n-1 gets s, others 0
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i == (num_stops - 1)) begin
                            latest_arrival[i] <= s;
                        end else begin
                            latest_arrival[i] <= 8'd0;
                        end
                    end
                    iter_count <= 3'd0;
                    change_detected <= 1'b0;
                    state <= PROCESSING;
                    line_index <= 3'd0;
                end

                PROCESSING: begin
                    // Loop through all lines for one BFS iteration
                    if (line_index < num_lines[2:0]) begin
                        // We are in UPDATE logic effectively, but piped to state UPDATE to avoid combinational loop
                        // Actually, let's perform the logic here or in UPDATE state
                        // Let's use UPDATE state for calculations to be clean
                        state <= UPDATE;
                    end else begin
                        // Finished checking all lines for this iteration
                        if (change_detected) begin
                            // Update the array with new values
                            for (i = 0; i < 8; i = i + 1) begin
                                latest_arrival[i] <= next_latest_arrival[i];
                            end
                            change_detected <= 1'b0;
                            iter_count <= iter_count + 1;
                            line_index <= 3'd0;
                            // Check max iterations (8)
                            if (iter_count == 3'd7) begin
                                // Reached max iterations, stop
                                state <= DONE;
                            end else begin
                                state <= PROCESSING; // Next iteration
                            end
                        end else begin
                            // No changes, algorithm converged
                            state <= DONE;
                        end
                    end
                end

                UPDATE: begin
                    // Process one line (line_index)
                    // Logic from combinational block is implicitly used here via current values
                    // We need to re-evaluate the combinational logic based on current line_index
                    // But since we are in sequential block, we replicate logic here or use intermediate vars
                    
                    // Note: To avoid complex combinational logic, we calculate here
                    // Redoing logic from combinational block to ensure correct latching
                    
                    // 1. Calculate target_time
                    if (latest_arrival[v[line_index]] > d[line_index]) begin
                        target_time = latest_arrival[v[line_index]] - d[line_index];
                    end else begin
                        target_time = 8'd0;
                    end

                    // 2. Calculate dep_time and arr_time
                    dep_time = 8'd0;
                    arr_time = 8'd0;
                    if (target_time >= t0[line_index]) begin
                        diff = target_time - t0[line_index];
                        if (p[line_index] != 8'd0) begin
                            k = diff / p[line_index];
                        end else begin
                            k = 8'd0;
                        end
                        dep_time = t0[line_index] + (k * p[line_index]);
                        arr_time = dep_time + d[line_index];
                    end

                    // 3. Update next_latest_arrival for u[line_index]
                    // Copy current value to next array if not already done
                    // (This is a bit tricky in single always block, we update delta)
                    // Optimization: Since we only process one line per cycle, we can check against current state
                    
                    // Actually, we need to store pending updates for the whole iteration.
                    // We will use next_latest_arrival array initialized to current latest_arrival at start of iteration?
                    // No, we initialized next_latest_arrival at start of iteration logic.
                    
                    // Let's manage next_latest_arrival content properly.
                    // We will initialize next_latest_arrival = latest_arrival at the start of PROCESSING cycle (line 0).
                    // Then in UPDATE, we modify it.
                    
                    // However, I am inside the state machine sequence. 
                    // To simplify: We will perform the update on 'latest_arrival' directly? 
                    // No, BFS usually requires synchronous update of all nodes for the iteration.
                    // Let's use a flag to indicate we need to initialize the shadow register.
                    
                    // If this is the first line of the iteration, we must initialize next_latest_arrival
                    if (line_index == 3'd0) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            next_latest_arrival[i] <= latest_arrival[i];
                        end
                    end

                    // Check if we found a valid time and it is better than what we have for u
                    if (target_time >= t0[line_index]) begin
                        // We have a valid tram connection
                        // Arrival at u is arr_time (which is dep_time + d)
                        // But wait, arr_time is the time we are at u? 
                        // No: We leave u at dep_time, arrive v at dep_time + d.
                        // Backwards: We are at v at time 'latest_arrival[v]', we can go back to u arriving at u at time 'dep_time + d'? 
                        // No, backwards means: 
                        // Forward: u (dep) -> v (arr)
                        // Backwards: v (arr) -> u (dep)
                        // We are at v at time 'latest_arrival[v]'. We need to leave u by 'target_time'.
                        // If we leave u at 'dep_time', we are at u at... we are AT u.
                        // So we are extending the reach of u.
                        // The 'new' latest arrival time for u is the departure time from u (dep_time).
                        // We want to maximize this.
                        
                        if (dep_time > next_latest_arrival[u[line_index]]) begin
                            next_latest_arrival[u[line_index]] <= dep_time;
                            change_detected <= 1'b1;
                        end
                    end

                    // Increment line index and return to PROCESSING
                    line_index <= line_index + 1;
                    state <= PROCESSING;
                end

                DONE: begin
                    // Final checks
                    valid <= 1'b1;
                    if (latest_arrival[0] == 8'd0 && (num_stops > 1)) begin
                        // If stop 0 has 0, it means unreachable (unless it is the destination)
                        if (num_stops == 1) begin
                            // If there is only 1 stop, we are there. Departure time is s (or s - travel time, but no travel)
                            // Requirement says: Departure from stop 0. If 0 is destination, we depart at s?
                            // The problem says 'departure from stop 0 to reach meeting'.
                            // If 0 is meeting, we don't need to depart? Let's assume we want time to leave.
                            // If meeting is at 0, we leave 0 at s (start of meeting)? Or we stay there.
                            // Let's output s.
                            latest_departure <= s;
                            impossible <= 1'b0;
                        end else begin
                            impossible <= 1'b1;
                        end
                    end else begin
                        impossible <= 1'b0;
                        // The problem asks for "latest departure time from hotel (stop 0)".
                        // In our BFS, latest_arrival[0] is the latest time we can BE at stop 0 to reach the meeting.
                        // Wait. If the meeting is at stop n-1, and we are at stop 0, we need to take trams.
                        // If latest_arrival[0] is X, that means we can be at stop 0 at time X and still make it.
                        // So the latest departure from stop 0 is X.
                        // However, if the meeting is AT stop 0 (n=1), we are already there. 
                        // The problem states "Departure from hotel (stop 0)". 
                        // Usually this implies time to leave 0. 
                        // If the algorithm computed latest_arrival[0] = s (meeting time), that means we can arrive at 0 at s and make it (meeting is at 0).
                        // So we should depart 0 at s.
                        // If we have to travel (e.g. 0->n-1), latest_arrival[0] is the latest departure time from 0.
                        latest_departure <= latest_arrival[0];
                    end
                    // Stay in DONE until reset
                end
            endcase
        end
    end

endmodule