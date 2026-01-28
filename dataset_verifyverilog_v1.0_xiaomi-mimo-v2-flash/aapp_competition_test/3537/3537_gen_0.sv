module flight_scheduler (
    input clk,
    input rst_n,
    input start,
    input [3:0] m_count,
    input [31:0] src,
    input [31:0] dst,
    input [31:0] dep,
    input [31:0] arr,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT       = 3'd1;
    localparam [2:0] PROCESS    = 3'd2;
    localparam [2:0] UPDATE     = 3'd3;
    localparam [2:0] CHECK      = 3'd4;
    localparam [2:0] FINISH     = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [4:0] flight_idx;           // 0 to 31 (5 bits for 32 flights)
    reg [4:0] country_idx;          // 0 to 15 (4 bits for 16 countries, but index is 0-based)
    
    // Frustration and arrival time arrays (16 countries, 0-15 indices)
    reg [31:0] frustration [0:15];  // 32-bit frustration values
    reg [10:0] arrival_time [0:11]; // 11-bit time (0-1023)
    
    // Flight data registers (single flight at a time)
    reg [3:0] current_src;
    reg [3:0] current_dst;
    reg [9:0] current_dep;          // 10-bit departure time
    reg [9:0] current_arr;          // 10-bit arrival time
    
    // Intermediate calculation registers
    reg [31:0] new_frustration;
    reg [31:0] old_frustration;
    reg [10:0] wait_time;
    reg [31:0] wait_squared;
    
    // Counter for initialization loop
    reg [3:0] init_counter;
    
    // Cycle counter for timeout prevention
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    integer i;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            flight_idx <= 5'd0;
            country_idx <= 5'd0;
            init_counter <= 4'd0;
            cycle_count <= 8'd0;
            current_src <= 4'd0;
            current_dst <= 4'd0;
            current_dep <= 10'd0;
            current_arr <= 10'd0;
            new_frustration <= 32'd0;
            old_frustration <= 32'd0;
            wait_time <= 11'd0;
            wait_squared <= 32'd0;
            // Initialize frustration array
            for (i = 0; i < 16; i = i + 1) begin
                frustration[i] <= 32'd0;
                arrival_time[i] <= 11'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    init_counter <= 4'd0;
                    flight_idx <= 5'd0;
                    country_idx <= 5'd0;
                    if (start) begin
                        // Start initialization sequence
                        // Country 0 (1) gets 0 frustration, others get INF
                        frustration[0] <= 32'd0;
                        arrival_time[0] <= 11'd0;
                        // Initialize other countries to infinity (max 32-bit)
                        // But we will handle this in INIT state
                    end
                end
                
                INIT: begin
                    // Initialize countries 1 to 15 (index 1-15)
                    if (init_counter < 4'd15) begin
                        frustration[init_counter + 4'd1] <= 32'hFFFFFFFF;
                        arrival_time[init_counter + 4'd1] <= 11'd0;
                        init_counter <= init_counter + 4'd1;
                    end else begin
                        init_counter <= 4'd0;
                    end
                end
                
                PROCESS: begin
                    // Extract current flight data
                    // We need to shift right by (31 - flight_idx) * 4 bits for 4-bit fields
                    // But we must calculate the shift amount dynamically
                    // For simplicity, we'll use a separate extraction logic
                    // This is handled in combinational logic below
                end
                
                UPDATE: begin
                    // Update frustration for destination country
                    // new_frustration is calculated in combinational block
                    frustration[current_dst] <= new_frustration;
                    arrival_time[current_dst] <= current_arr;
                end
                
                CHECK: begin
                    // Move to next flight
                    flight_idx <= flight_idx + 5'd1;
                end
                
                FINISH: begin
                    // Output result for destination country n (country 16 = index 15)
                    result <= frustration[15];
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Combinational next state logic
    always @(*) begin
        next_state = state; // Default to stay in current state
        
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT;
                else
                    next_state = IDLE;
            end
            
            INIT: begin
                if (init_counter >= 4'd15)
                    next_state = PROCESS;
                else
                    next_state = INIT;
            end
            
            PROCESS: begin
                // Transition to update if source is reachable
                // and wait time is valid (>= 0)
                if (flight_idx < m_count) begin
                    if (frustration[current_src] != 32'hFFFFFFFF && 
                        current_dep >= arrival_time[current_src]) begin
                        next_state = UPDATE;
                    end else begin
                        // Source not reachable or invalid wait time, skip
                        next_state = CHECK;
                    end
                end else begin
                    // All flights processed
                    next_state = FINISH;
                end
            end
            
            UPDATE: begin
                // Always go to CHECK after update
                next_state = CHECK;
            end
            
            CHECK: begin
                next_state = PROCESS;
            end
            
            FINISH: begin
                // Return to IDLE after done pulse
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
        
        // Timeout prevention
        if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
            next_state = FINISH; // Force finish to avoid hanging
        end
    end

    // Extract flight data from 32-bit arrays
    // Each element is 4 or 10 bits, packed in 32-bit register
    always @(*) begin
        // Calculate bit positions
        // flight_idx is 0-31, we extract bits [4*idx+3 : 4*idx] for 4-bit fields
        // and [10*idx+9 : 10*idx] for 10-bit fields
        
        // Extract 4-bit source (starting from MSB of src[31:0])
        // Actually, spec says src[31:0] is an array of 32 elements of 4 bits each
        // So src[3:0] = element 0, src[7:4] = element 1, etc.
        // But typically in packed arrays, lower bits = first element
        // Let's assume src[3:0] = flight 0, src[7:4] = flight 1...
        
        // For flight_idx, we extract bits [4*flight_idx+3 : 4*flight_idx]
        if (flight_idx < 5'd32) begin
            current_src = src[4*flight_idx +: 4];
            current_dst = dst[4*flight_idx +: 4];
            current_dep = dep[10*flight_idx +: 10];
            current_arr = arr[10*flight_idx +: 10];
        end else begin
            current_src = 4'd0;
            current_dst = 4'd0;
            current_dep = 10'd0;
            current_arr = 10'd0;
        end
    end

    // Calculation logic
    always @(*) begin
        // Initialize to avoid latches
        old_frustration = 32'd0;
        wait_time = 11'd0;
        wait_squared = 32'd0;
        new_frustration = 32'd0;
        
        // Get current source frustration
        old_frustration = frustration[current_src];
        
        // Calculate wait time
        wait_time = current_dep - arrival_time[current_src];
        
        // Calculate squared wait time (10-bit * 10-bit = 20-bit, but result can be up to 1023^2 = 1,046,529 which fits in 32 bits)
        wait_squared = wait_time * wait_time;
        
        // Calculate new frustration
        new_frustration = old_frustration + wait_squared;
    end

endmodule