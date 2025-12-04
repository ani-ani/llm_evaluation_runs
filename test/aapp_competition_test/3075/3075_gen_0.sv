module gas_station_optimizer(
    input  clk,
    input  rst_n,
    input  start,
    input  [3:0]  n,
    input  [15:0] g,
    input  [15:0] d [0:7],
    input  [15:0] c [0:7],
    output reg [31:0] total_cost,
    output reg        error,
    output reg        done
);

    // State encoding
    localparam IDLE         = 3'd0;
    localparam INIT         = 3'd1;
    localparam FIND_CHEAPER = 3'd2;
    localparam REFUEL       = 3'd3;
    localparam UPDATE       = 3'd4;
    localparam DONE         = 3'd5;

    reg [2:0] state, next_state;

    // Internal registers
    reg [3:0]  cur_idx;           // current station index
    reg [3:0]  cheaper_idx;       // index of selected cheaper station / fallback
    reg        cheaper_found;     // flag for cheaper station existence
    reg [3:0]  scan_idx;          // scanning index in FIND_CHEAPER

    reg [15:0] cur_pos;           // current position (distance)
    reg [31:0] fuel;              // current fuel (widened to avoid overflow)
    reg [31:0] cap;               // capacity (copy of g)
    reg [31:0] nxt_dist;          // next chosen station distance
    reg [31:0] fuel_needed;       // fuel required to reach chosen station

    reg [31:0] total_cost_next;
    reg [31:0] fuel_next;
    reg [3:0]  cur_idx_next;
    reg [3:0]  scan_idx_next;
    reg [15:0] cur_pos_next;
    reg [3:0]  cheaper_idx_next;
    reg        cheaper_found_next;
    reg        error_next;
    reg        done_next;

    // Combinational state transition and control
    always @* begin
        // Defaults: hold values
        next_state         = state;
        total_cost_next    = total_cost;
        fuel_next          = fuel;
        cur_idx_next       = cur_idx;
        scan_idx_next      = scan_idx;
        cur_pos_next       = cur_pos;
        cheaper_idx_next   = cheaper_idx;
        cheaper_found_next = cheaper_found;
        error_next         = error;
        done_next          = done;
        nxt_dist           = nxt_dist;      // keep last unless updated
        fuel_needed        = fuel_needed;   // keep last unless updated

        case (state)
            IDLE: begin
                done_next      = 1'b0;
                error_next     = 1'b0;
                if (start) begin
                    next_state      = INIT;
                end
            end

            INIT: begin
                // Initialize journey
                total_cost_next    = 32'd0;
                cap                = {16'd0, g};
                fuel_next          = {16'd0, g};
                cur_idx_next       = 4'd0;
                cur_pos_next       = 16'd0;
                cheaper_found_next = 1'b0;
                cheaper_idx_next   = 4'd0;
                scan_idx_next      = 4'd0;
                error_next         = 1'b0;
                done_next          = 1'b0;

                // If no stations or n==0, immediate error (cannot model destination)
                if (n == 4'd0) begin
                    error_next    = 1'b1;
                    total_cost_next = 32'hFFFFFFFF;
                    next_state    = DONE;
                end else begin
                    next_state    = FIND_CHEAPER;
                end
            end

            FIND_CHEAPER: begin
                // If journey complete: reached last station index n-1 and no further destination defined
                if (cur_idx == (n - 1)) begin
                    // Completed processing
                    next_state   = DONE;
                    done_next    = 1'b1;
                end else begin
                    // One-step iterative search; complete within <=8 cycles
                    // Initialize scan on entry when scan_idx == 0
                    if (scan_idx == 4'd0) begin
                        cheaper_found_next = 1'b0;
                        cheaper_idx_next   = cur_idx + 1'b1;
                        scan_idx_next      = cur_idx + 1'b1;
                    end else begin
                        scan_idx_next = scan_idx;
                    end

                    // Only search while within bounds
                    if (scan_idx_next <= (n - 1)) begin
                        // Distance from current position to candidate station
                        // Protect against underflow; d[] are ascending and cur_pos <= d[cur_idx]
                        // dist_to_candidate = d[scan_idx] - cur_pos
                        // Check reachability within tank capacity
                        if (({16'd0, d[scan_idx_next]} >= {16'd0, cur_pos}) &&
                            (({16'd0, d[scan_idx_next]} - {16'd0, cur_pos}) <= cap)) begin
                            // Check if cheaper cost exists
                            if (c[scan_idx_next] < c[cur_idx]) begin
                                cheaper_found_next = 1'b1;
                                cheaper_idx_next   = scan_idx_next;
                                // Search done once a first cheaper within range is found
                                // Decide next state
                                // Compute chosen next distance
                                nxt_dist    = {16'd0, d[cheaper_idx_next]};
                                fuel_needed = (nxt_dist - {16'd0, cur_pos});
                                next_state  = REFUEL;
                            end else begin
                                // Continue search next cycle
                                scan_idx_next = scan_idx_next + 1'b1;
                                // If reached end without cheaper, fall back afterward
                                if (scan_idx_next > (n - 1)) begin
                                    cheaper_found_next = 1'b0;
                                    cheaper_idx_next   = cur_idx + 1'b1;
                                    nxt_dist    = {16'd0, d[cur_idx + 1'b1]};
                                    fuel_needed = (nxt_dist - {16'd0, cur_pos});
                                    next_state  = REFUEL;
                                end
                            end
                        end else begin
                            // Candidate not reachable within capacity, move scan forward
                            scan_idx_next = scan_idx_next + 1'b1;
                            // If none reachable/cheaper found by end
                            if (scan_idx_next > (n - 1)) begin
                                // No further reachable station within capacity -> error
                                error_next       = 1'b1;
                                total_cost_next  = 32'hFFFFFFFF;
                                next_state       = DONE;
                            end
                        end
                    end else begin
                        // Finished scanning without finding candidate
                        // No reachable station -> error
                        error_next      = 1'b1;
                        total_cost_next = 32'hFFFFFFFF;
                        next_state      = DONE;
                    end
                end
            end

            REFUEL: begin
                // At this point, cheaper_idx is selected (either cheaper or next)
                // nxt_dist and fuel_needed are valid: required fuel to reach chosen station

                // Check basic reachability from capacity
                if (fuel_needed > cap) begin
                    // Even full tank can't reach chosen station -> error
                    error_next      = 1'b1;
                    total_cost_next = 32'hFFFFFFFF;
                    next_state      = DONE;
                end else begin
                    // If current fuel is sufficient, no refuel
                    if (fuel >= fuel_needed) begin
                        // No cost added
                        next_state = UPDATE;
                    end else begin
                        // Need to buy (fuel_needed - fuel) from current station
                        // Clamp to capacity
                        reg [31:0] required;
                        reg [31:0] buy;
                        required = fuel_needed;
                        // buy = min(required - fuel, cap - fuel)
                        if (required > fuel) begin
                            if ((required - fuel) <= (cap - fuel))
                                buy = required - fuel;
                            else
                                buy = cap - fuel;
                        end else begin
                            buy = 32'd0;
                        end

                        // Compute additional cost with protection
                        // cost_add = buy * c[cur_idx]
                        reg [31:0] cost_add;
                        cost_add = buy * {16'd0, c[cur_idx]};

                        // Saturating addition into total_cost_next (wrap-prevent)
                        if (32'hFFFFFFFF - total_cost < cost_add)
                            total_cost_next = 32'hFFFFFFFF;
                        else
                            total_cost_next = total_cost + cost_add;

                        // Update fuel (still in REFUEL state)
                        // fuel = fuel + buy (bounded by cap)
                        if (fuel + buy > cap)
                            fuel_next = cap;
                        else
                            fuel_next = fuel + buy;

                        next_state = UPDATE;
                    end
                end
            end

            UPDATE: begin
                // Move to chosen station and consume fuel_needed
                // Recompute nxt_dist and fuel_needed safely based on cheaper_idx
                nxt_dist    = {16'd0, d[cheaper_idx]};
                if (nxt_dist >= {16'd0, cur_pos})
                    fuel_needed = nxt_dist - {16'd0, cur_pos};
                else
                    fuel_needed = 32'd0; // protection

                // Check reachability with current fuel
                if (fuel < fuel_needed) begin
                    error_next      = 1'b1;
                    total_cost_next = 32'hFFFFFFFF;
                    next_state      = DONE;
                end else begin
                    // Update fuel and position
                    fuel_next    = fuel - fuel_needed;
                    cur_pos_next = d[cheaper_idx];
                    cur_idx_next = cheaper_idx;

                    // Prepare for next search
                    scan_idx_next      = 4'd0;
                    cheaper_found_next = 1'b0;
                    cheaper_idx_next   = 4'd0;

                    // If last station reached, complete
                    if (cur_idx_next == (n - 1)) begin
                        done_next  = 1'b1;
                        next_state = DONE;
                    end else begin
                        next_state = FIND_CHEAPER;
                    end
                end
            end

            DONE: begin
                done_next = 1'b1;
                // Wait for next start (synchronous restart)
                if (start) begin
                    next_state = INIT;
                    done_next  = 1'b0;
                    error_next = 1'b0;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= IDLE;
            total_cost     <= 32'd0;
            fuel           <= 32'd0;
            cur_idx        <= 4'd0;
            scan_idx       <= 4'd0;
            cur_pos        <= 16'd0;
            cheaper_idx    <= 4'd0;
            cheaper_found  <= 1'b0;
            error          <= 1'b0;
            done           <= 1'b0;
            nxt_dist       <= 32'd0;
            fuel_needed    <= 32'd0;
            cap            <= 32'd0;
        end else begin
            state          <= next_state;
            total_cost     <= total_cost_next;
            fuel           <= fuel_next;
            cur_idx        <= cur_idx_next;
            scan_idx       <= scan_idx_next;
            cur_pos        <= cur_pos_next;
            cheaper_idx    <= cheaper_idx_next;
            cheaper_found  <= cheaper_found_next;
            error          <= error_next;
            done           <= done_next;
        end
    end

endmodule