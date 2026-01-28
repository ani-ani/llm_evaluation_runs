module ChameleonSimulator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire inputs_valid,
    input wire [15:0] d [0:15],
    input wire [2:0] b [0:15],
    input wire [0:0] dir [0:15],
    input wire [3:0] len,
    output reg [31:0] total_trip [0:7],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] SIMULATE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;
    
    reg [1:0] state, next_state;
    
    // Chameleon data registers
    reg [15:0] pos [0:15];
    reg [2:0] color [0:15];
    reg [0:0] direction [0:15];
    reg [0:0] active [0:15];
    
    // Simulation parameters
    reg [15:0] stick_length;
    reg [11:0] cycle_count;
    localparam [11:0] MAX_CYCLES = 12'd4096;
    
    // Fixed-point constants
    localparam [15:0] ONE_Q8_8 = 16'd256;
    localparam [31:0] ONE_Q16_16 = 32'd65536;
    localparam [15:0] EPSILON_Q8_8 = 16'd1;
    
    // Temporary variables for collision detection
    reg [31:0] min_dt;
    reg [3:0] colliding_pair_i;
    reg [3:0] colliding_pair_j;
    reg [0:0] collision_detected;
    reg [0:0] boundary_detected;
    reg [3:0] boundary_index;
    
    // Initialize all registers
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            cycle_count <= 12'd0;
            
            // Initialize chameleon data
            for (i = 0; i < 16; i = i + 1) begin
                pos[i] <= 16'd0;
                color[i] <= 3'd0;
                direction[i] <= 1'b0;
                active[i] <= 1'b0;
            end
            
            // Initialize total_trip
            for (i = 0; i < 8; i = i + 1) begin
                total_trip[i] <= 32'd0;
            end
            
            stick_length <= 16'd256;
            min_dt <= 32'd0;
            colliding_pair_i <= 4'd0;
            colliding_pair_j <= 4'd0;
            collision_detected <= 1'b0;
            boundary_detected <= 1'b0;
            boundary_index <= 4'd0;
        end else begin
            state <= next_state;
        end
    end
    
    // Load input data
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized
        end else if (state == LOAD && inputs_valid) begin
            for (i = 0; i < 16; i = i + 1) begin
                if (i < len) begin
                    pos[i] <= d[i];
                    color[i] <= b[i];
                    direction[i] <= dir[i];
                    active[i] <= 1'b1;
                end else begin
                    active[i] <= 1'b0;
                end
            end
            next_state <= SIMULATE;
        end
    end
    
    // Main simulation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized
        end else if (state == SIMULATE) begin
            // Reset detection flags
            collision_detected <= 1'b0;
            boundary_detected <= 1'b0;
            min_dt <= 32'd0;
            
            // Check for boundary exits
            for (i = 0; i < 16; i = i + 1) begin
                if (active[i]) begin
                    if (direction[i] == 1'b0) begin
                        // Moving left
                        if (pos[i] < ONE_Q8_8) begin
                            boundary_detected <= 1'b1;
                            boundary_index <= i;
                        end
                    end else begin
                        // Moving right
                        if (pos[i] > (stick_length - ONE_Q8_8)) begin
                            boundary_detected <= 1'b1;
                            boundary_index <= i;
                        end
                    end
                end
            end
            
            // Check for collisions
            for (i = 0; i < 15; i = i + 1) begin
                if (active[i]) begin
                    for (j = i + 1; j < 16; j = j + 1) begin
                        if (active[j]) begin
                            // Calculate relative velocity and distance
                            reg signed [15:0] dx;
                            reg signed [15:0] dv;
                            reg signed [31:0] dt;
                            
                            dx = pos[j] - pos[i];
                            dv = (direction[j] == 1'b1 ? ONE_Q8_8 : -ONE_Q8_8) - 
                                (direction[i] == 1'b1 ? ONE_Q8_8 : -ONE_Q8_8);
                            
                            // Avoid division by zero
                            if (dv != 16'd0 && dx != 16'd0) begin
                                // Fixed-point division: dx / dv
                                reg signed [31:0] dx_ext;
                                reg signed [31:0] dv_ext;
                                reg signed [31:0] quotient;
                                
                                dx_ext = {{16{dx[15]}}, dx};
                                dv_ext = {{16{dv[15]}}, dv};
                                
                                // Simple division approximation (for synthesis)
                                quotient = dx_ext / dv_ext;
                                
                                // Ensure positive time
                                if (quotient > 32'd0 && quotient < min_dt) begin
                                    min_dt <= quotient;
                                    colliding_pair_i <= i;
                                    colliding_pair_j <= j;
                                    collision_detected <= 1'b1;
                                end
                            end
                        end
                    end
                end
            end
            
            // Determine next step
            if (boundary_detected || collision_detected) begin
                reg [31:0] delta_t;
                
                if (boundary_detected && (!collision_detected || min_dt == 32'd0)) begin
                    // Handle boundary exit
                    delta_t <= 32'd0;
                    active[boundary_index] <= 1'b0;
                end else if (collision_detected) begin
                    // Handle collision
                    delta_t <= min_dt;
                    
                    // Update positions
                    for (i = 0; i < 16; i = i + 1) begin
                        if (active[i]) begin
                            reg signed [15:0] vel;
                            vel = (direction[i] == 1'b1) ? ONE_Q8_8 : -ONE_Q8_8;
                            pos[i] <= pos[i] + (vel * delta_t[31:16]);
                            
                            // Update total_trip
                            total_trip[color[i]] <= total_trip[color[i]] + delta_t;
                        end
                    end
                    
                    // Swap directions and colors
                    i = colliding_pair_i;
                    j = colliding_pair_j;
                    
                    // Swap directions
                    direction[i] <= !direction[i];
                    direction[j] <= !direction[j];
                    
                    // Update colors
                    reg [2:0] temp_color;
                    temp_color = color[j];
                    color[i] <= temp_color;
                    color[j] <= (color[i] + temp_color) % 8;
                end
                
                // Check if all chameleons are inactive
                reg [0:0] all_inactive;
                all_inactive = 1'b1;
                for (i = 0; i < 16; i = i + 1) begin
                    if (active[i]) begin
                        all_inactive = 1'b0;
                    end
                end
                
                if (all_inactive || cycle_count >= MAX_CYCLES) begin
                    next_state <= DONE_STATE;
                end
                
                cycle_count <= cycle_count + 12'd1;
            end else begin
                // No collisions or boundaries - simulation complete
                next_state <= DONE_STATE;
            end
        end else if (state == DONE_STATE) begin
            done <= 1'b1;
            next_state <= IDLE;
        end else if (state == IDLE && start) begin
            next_state <= LOAD;
            done <= 1'b0;
            cycle_count <= 12'd0;
        end
    end
endmodule