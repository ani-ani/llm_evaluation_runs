module ChameleonSimulator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire inputs_valid,
    input wire [15:0] d [0:15],
    input wire [2:0] b [0:15],
    input wire [0:15] dir,
    input wire [3:0] len,
    output reg [31:0] total_trip [0:7],
    output reg done
);

    // --- Parameters ---
    localparam [7:0] MAX_CYCLES = 8'd128;
    localparam [3:0] K_MAX = 4'd8;
    localparam [15:0] EPSILON = 16'd1; // Q8.8 representation of 1/256
    
    // --- State Machine ---
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] STORE_INPUTS = 3'd1;
    localparam [2:0] FIND_NEXT_EVENT = 3'd2;
    localparam [2:0] UPDATE_STATE = 3'd3;
    localparam [2:0] HANDLE_COLLISIONS = 3'd4;
    localparam [2:0] HANDLE_BOUNDARIES = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    reg [2:0] state, next_state;
    
    // --- Registers (Storage) ---
    reg signed [15:0] pos_reg [0:15]; // Q8.8
    reg [2:0] color_reg [0:15];
    reg [0:15] dir_reg;
    reg [0:15] active_reg;
    reg [31:0] trip_reg [0:7]; // Q16.16
    
    // --- Counters & Indices ---
    reg [3:0] i, j;
    reg [7:0] cycle_count;
    reg [3:0] active_count;
    reg [3:0] k_idx;
    
    // --- Fixed-Point Intermediate Registers ---
    reg signed [31:0] dt_collision; // Q16.16
    reg signed [31:0] dt_exit;      // Q16.16
    reg signed [31:0] delta_t;      // Q16.16
    
    // Computation signals
    reg signed [15:0] dx; // Q8.8
    reg signed [31:0] dt_calc; // Q16.16
    reg signed [31:0] vel_mult; // Q16.16 (vel * delta_t)
    
    // --- Helper Registers for Min Finding ---
    reg signed [31:0] min_dt;
    reg [3:0] min_i;
    reg [3:0] min_j;
    reg event_is_collision;
    reg event_is_exit;
    reg signed [15:0] exit_pos;
    reg signed [31:0] exit_vel; // Q16.16
    
    // --- Collision Detection State ---
    reg collision_found;
    
    // --- Reset Initialization ---
    integer init_idx;
    
    // --- Main FSM Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            active_count <= 4'd0;
            
            // Initialize arrays
            for (init_idx = 0; init_idx < 16; init_idx = init_idx + 1) begin
                pos_reg[init_idx] <= 16'd0;
                color_reg[init_idx] <= 3'd0;
                dir_reg[init_idx] <= 1'b0;
                active_reg[init_idx] <= 1'b0;
            end
            for (init_idx = 0; init_idx < 8; init_idx = init_idx + 1) begin
                total_trip[init_idx] <= 32'd0;
                trip_reg[init_idx] <= 32'd0;
            end
            
            i <= 4'd0;
            j <= 4'd0;
            k_idx <= 4'd0;
            
            dt_collision <= 32'h7FFFFFFF;
            dt_exit <= 32'h7FFFFFFF;
            delta_t <= 32'd0;
            
            min_dt <= 32'h7FFFFFFF;
            min_i <= 4'd0;
            min_j <= 4'd0;
            event_is_collision <= 1'b0;
            event_is_exit <= 1'b0;
            exit_pos <= 16'd0;
            exit_vel <= 32'd0;
            
            dx <= 16'd0;
            dt_calc <= 32'd0;
            vel_mult <= 32'd0;
            
            collision_found <= 1'b0;
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start && inputs_valid) begin
                        state <= STORE_INPUTS;
                        i <= 4'd0;
                        active_count <= 4'd0;
                        // Reset trip counts
                        for (init_idx = 0; init_idx < 8; init_idx = init_idx + 1) begin
                            trip_reg[init_idx] <= 32'd0;
                        end
                    end else begin
                        state <= IDLE;
                    end
                end

                STORE_INPUTS: begin
                    if (i < len) begin
                        pos_reg[i] <= d[i];
                        color_reg[i] <= b[i];
                        dir_reg[i] <= dir[i];
                        active_reg[i] <= 1'b1;
                        active_count <= active_count + 4'd1;
                        i <= i + 4'd1;
                    end else begin
                        i <= 4'd0;
                        state <= FIND_NEXT_EVENT;
                        cycle_count <= 8'd0;
                    end
                end

                FIND_NEXT_EVENT: begin
                    // Check termination
                    if (active_count == 4'd0 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        // Initialize min search
                        min_dt <= 32'h7FFFFFFF;
                        min_i <= 4'd0;
                        min_j <= 4'd0;
                        event_is_collision <= 1'b0;
                        event_is_exit <= 1'b0;
                        i <= 4'd0;
                        state <= HANDLE_BOUNDARIES; // Start with boundaries (simpler loop structure)
                    end
                end

                HANDLE_BOUNDARIES: begin
                    // Sequential scan for exit times
                    if (i < len) begin
                        if (active_reg[i]) begin
                            // Calculate dt_exit
                            // vel[i] is +1 (R) or -1 (L) in Q16.16
                            exit_vel = dir_reg[i] ? 32'h00010000 : -32'h00010000;
                            exit_pos = dir_reg[i] ? (16'd256 << 8) : 16'd0; // L=256 in Q8.8
                            
                            // dx = exit_pos - pos (Q8.8)
                            dx = exit_pos - pos_reg[i];
                            
                            // dt = dx / vel (Q16.16)
                            // vel is +/- 1.0. Shift dx left 8 bits to match Q16.16
                            dt_calc = {dx, 8'd0}; // dx in Q16.16
                            
                            if (exit_vel[31]) begin
                                dt_calc = -dt_calc;
                            end
                            
                            // Check if valid future exit
                            if (dt_calc > 0 && dt_calc < min_dt) begin
                                min_dt <= dt_calc;
                                min_i <= i;
                                event_is_collision <= 1'b0;
                                event_is_exit <= 1'b1;
                            end
                        end
                        i <= i + 4'd1;
                    end else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        state <= HANDLE_COLLISIONS;
                    end
                end

                HANDLE_COLLISIONS: begin
                    // Iterate pairs (i, j) where i < j
                    // Need nested loops. 
                    // Since loops are hard in single always block without FSM states,
                    // we simulate a loop structure.
                    
                    // Find next valid pair
                    collision_found <= 1'b0;
                    if (i >= len - 1) begin
                        // Done checking collisions
                        if (min_dt == 32'h7FFFFFFF) begin
                            // No events found, break
                            active_count <= 4'd0; // Force stop
                            state <= FINISH;
                        end else begin
                            state <= UPDATE_STATE;
                        end
                    end else begin
                        if (active_reg[i] && active_reg[j] && (dir_reg[i] != dir_reg[j])) begin
                            // Calculate dt
                            // dx = pos[j] - pos[i] (since j > i usually, but positions can swap)
                            // Relative velocity dv = vel[j] - vel[i]
                            // If dir[i] != dir[j], dv is +/- 2.0 (Q16.16: 0x00020000)
                            // dt = dx / dv
                            
                            // Ensure dx is positive (j ahead of i)
                            // But collision happens when distance closes. 
                            // If dir[i]=R(1), dir[j]=L(0): i moves right, j moves left. Collision if pos[j] > pos[i].
                            // If dir[i]=L(0), dir[j]=R(1): i moves left, j moves right. Collision if pos[i] > pos[j].
                            
                            if (dir_reg[i] == 1 && dir_reg[j] == 0) begin // i->, j<-, j ahead
                                if (pos_reg[j] > pos_reg[i]) begin
                                    dx = pos_reg[j] - pos_reg[i];
                                    // dv = -1 - (+1) = -2. dt = dx / (-2) -> negative if dx>0. 
                                    // Wait, time to collision is positive. 
                                    // dx = distance. dv = closing speed = 2. 
                                    // dt = dx / 2.
                                    dt_calc = {dx, 8'd0}; // dx in Q16.16
                                    dt_calc = dt_calc >>> 1; // Divide by 2
                                    if (dt_calc < min_dt) begin
                                        min_dt <= dt_calc;
                                        min_i <= i;
                                        min_j <= j;
                                        event_is_collision <= 1'b1;
                                        event_is_exit <= 1'b0;
                                        collision_found <= 1'b1;
                                    end
                                end
                            end else if (dir_reg[i] == 0 && dir_reg[j] == 1) begin // i<-, j->, i ahead
                                if (pos_reg[i] > pos_reg[j]) begin
                                    dx = pos_reg[i] - pos_reg[j];
                                    dt_calc = {dx, 8'd0};
                                    dt_calc = dt_calc >>> 1;
                                    if (dt_calc < min_dt) begin
                                        min_dt <= dt_calc;
                                        min_i <= i;
                                        min_j <= j;
                                        event_is_collision <= 1'b1;
                                        event_is_exit <= 1'b0;
                                        collision_found <= 1'b1;
                                    end
                                end
                            end
                        end
                        
                        // Increment pair indices
                        j <= j + 4'd1;
                        if (j >= len - 1) begin
                            i <= i + 4'd1;
                            j <= i + 4'd2;
                        end
                    end
                end

                UPDATE_STATE: begin
                    // 1. Add trip distances for all active chameleons
                    // trip_reg[color] += delta_t (Q16.16)
                    // Since we only update trips when we advance time (min_dt),
                    // we do this in a loop or sub-state. 
                    // For simplicity, we'll assume delta_t is min_dt.
                    // We need to iterate over all active chameleons to update positions AND trips.
                    
                    // We will use a helper loop state. 
                    // But first, set delta_t = min_dt
                    delta_t <= min_dt;
                    
                    // Reset i for the update loop
                    i <= 4'd0;
                    state <= UPDATE_STATE; // Stay in this logic block? No, better to move to a sub-loop state
                    
                    // Actually, let's make UPDATE_STATE a loop over active chameleons
                    // We need a state transition to loop.
                    // Let's create a state UPDATE_LOOP
                    state <= UPDATE_LOOP;
                end
                
                UPDATE_LOOP: begin
                    if (i < len) begin
                        if (active_reg[i]) begin
                            // Update Trip
                            trip_reg[color_reg[i]] <= trip_reg[color_reg[i]] + delta_t;
                            
                            // Update Position
                            // vel = +1 (R) or -1 (L) in Q16.16
                            // pos += vel * delta_t
                            // vel * delta_t: 32-bit result. 
                            // Since vel is +/- 1.0 (0x00010000), product is +/- delta_t.
                            // Result is Q16.16. To add to Q8.8 pos, shift right 8 bits.
                            
                            if (dir_reg[i]) begin // Right
                                pos_reg[i] <= pos_reg[i] + (delta_t >>> 8);
                            end else begin // Left
                                pos_reg[i] <= pos_reg[i] - (delta_t >>> 8);
                            end
                        end
                        i <= i + 4'd1;
                    end else begin
                        // Done updating positions
                        cycle_count <= cycle_count + 8'd1;
                        
                        if (event_is_collision) begin
                            state <= COLLISION_RESPONSE;
                            i <= min_i;
                            j <= min_j;
                        end else if (event_is_exit) begin
                            state <= EXIT_RESPONSE;
                            i <= min_i;
                        end else begin
                            // Should not happen
                            state <= FIND_NEXT_EVENT;
                        end
                    end
                end

                COLLISION_RESPONSE: begin
                    // Swap Directions
                    dir_reg[i] <= dir_reg[j];
                    dir_reg[j] <= dir_reg[i];
                    
                    // Update Colors
                    // b[i] = b[j]
                    // b[j] = (b[i] + b[j]) % K
                    // Must use old values for calculation.
                    // Since we are changing them simultaneously in registers, 
                    // we need to capture old values or sequence it carefully.
                    
                    // Let's sequence it:
                    // Step 1: b[i] gets old b[j]
                    color_reg[i] <= color_reg[j];
                    
                    // Step 2: b[j] gets (old b[i] + old b[j]) % K
                    // Since color_reg[i] hasn't updated yet in hardware (it updates on clock edge),
                    // we can read the old value from color_reg[i].
                    // But we just assigned color_reg[i] <= color_reg[j]. 
                    // In Verilog simulation, this schedules an update. The current value of color_reg[i] is still the old one.
                    // So we can use it.
                    
                    color_reg[j] <= (color_reg[i] + color_reg[j]) % K_MAX;
                    
                    // Next state
                    state <= FIND_NEXT_EVENT;
                end

                EXIT_RESPONSE: begin
                    // Mark inactive
                    active_reg[i] <= 1'b0;
                    active_count <= active_count - 4'd1;
                    
                    state <= FIND_NEXT_EVENT;
                end

                FINISH: begin
                    // Copy trip_reg to output total_trip
                    // We need to wait for the loop to finish, but since arrays are small, 
                    // we can do it in one cycle or use a counter.
                    // Let's use k_idx counter.
                    if (k_idx < K_MAX) begin
                        total_trip[k_idx] <= trip_reg[k_idx];
                        k_idx <= k_idx + 4'd1;
                    end else begin
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule