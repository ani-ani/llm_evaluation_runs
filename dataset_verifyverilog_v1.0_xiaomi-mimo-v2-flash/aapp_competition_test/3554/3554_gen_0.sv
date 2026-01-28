module smoothie_transport (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] D_in,
    input wire [31:0] W_in,
    input wire [31:0] C_in,
    output reg [63:0] result_high,
    output reg [63:0] result_low,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_LOOP = 3'd1;
    localparam [2:0] FINAL_CALC = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Internal registers for 64-bit precision (scaled by 10^9)
    reg [2:0] state;
    reg [63:0] dist_rem;
    reg [63:0] fuel_rem;
    reg [63:0] capacity;
    reg [63:0] delivered;
    
    // Loop variables
    reg [63:0] n;
    reg [63:0] step;
    reg [63:0] trips;
    reg [63:0] temp_calc;
    
    // Constants
    localparam [63:0] SCALE = 1000000000; // 10^9
    localparam [63:0] TWO = 2;
    localparam [63:0] ONE = 1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_high <= 64'd0;
            result_low <= 64'd0;
            dist_rem <= 64'd0;
            fuel_rem <= 64'd0;
            capacity <= 64'd0;
            delivered <= 64'd0;
            n <= 64'd0;
            step <= 64'd0;
            trips <= 64'd0;
            temp_calc <= 64'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Scale inputs to 64-bit integers with scale factor
                        // Inputs D_in, W_in, C_in are assumed to be raw integer values
                        // We multiply by SCALE to get precision
                        dist_rem <= {D_in, 32'b0}; // D_in * 2^32 is roughly scale if D_in is float, but here we assume integer inputs
                        // Correction: If inputs are integers 1..10^6, we simply multiply by SCALE
                        // Input width 32 bits is sufficient for 10^6.
                        // dist_rem <= D_in * SCALE;
                        // Since multiplication might overflow 32x64 in standard synthesis without DSPs, 
                        // but inputs are 32-bit and SCALE fits, we do:
                        dist_rem <= D_in * SCALE;
                        fuel_rem <= W_in * SCALE;
                        capacity <= C_in * SCALE;
                        delivered <= 64'd0;
                        
                        if (W_in * SCALE <= C_in * SCALE) begin
                            state <= FINAL_CALC;
                        end else begin
                            state <= CALC_LOOP;
                        end
                    end
                end

                CALC_LOOP: begin
                    // Check if fuel_rem > capacity
                    // We compute n = ceil(fuel_rem / capacity)
                    // In integer arithmetic: n = (fuel_rem + capacity - 1) / capacity
                    temp_calc <= (fuel_rem + capacity - ONE);
                    
                    // Next state: Compute n and step
                    // We split this into multiple states to avoid complex combinational logic
                    // or just use a multi-cycle combinational block. Here we assume sequential update.
                    // Since state transition is combinational logic in the always block based on inputs,
                    // we need to be careful not to create long paths.
                    // Let's compute n directly in the next cycle.
                    
                    if (fuel_rem > capacity) begin
                        n <= (fuel_rem + capacity - ONE) / capacity;
                        state <= CALC_LOOP; // Stay here to compute step in next cycle
                        
                        // Compute trips = 2*n - 1
                        // This requires n to be valid.
                        // We'll use a sub-state or a flag. 
                        // To keep it simple and compliant: use flags or multiple states.
                        // Let's introduce a 'sub_state' or just use the main state with a 'valid' flag.
                        // Actually, standard Verilog allows multiple assignments in a state.
                        // We calculate n in this cycle.
                    end else begin
                        state <= FINAL_CALC;
                    end
                end

                // We need a state to handle the division and comparison for the loop logic
                // because division is expensive and we can't do it combinationally in one cycle easily.
                // However, for this problem, we can rely on the fact that the loop depth is small.
                // Let's restructure CALC_LOOP to perform one iteration per cycle.
                // We need a state to calculate 'step' (C / trips).
                // State CALC_STEP:
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // To adhere strictly to the state machine requirements and avoid combinational loops,
    // let's define a cleaner FSM with explicit states for the loop operations.
    // This overrides the previous always block for correct logic.
    
endmodule

// Redefining the module to ensure correctness and compliance with FSM rules
module smoothie_transport (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] D_in,
    input wire [31:0] W_in,
    input wire [31:0] C_in,
    output reg [63:0] result_high,
    output reg [63:0] result_low,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_COND = 3'd1;
    localparam [2:0] CALC_N = 3'd2;
    localparam [2:0] CALC_TRIPS = 3'd3;
    localparam [2:0] CALC_STEP = 3'd4;
    localparam [2:0] UPDATE_LOOP = 3'd5;
    localparam [2:0] FINAL_CALC = 3'd6;
    localparam [2:0] FINISH = 3'd7;

    reg [2:0] state;
    reg [63:0] dist_rem;
    reg [63:0] fuel_rem;
    reg [63:0] capacity;
    
    // Intermediate calculation registers
    reg [63:0] n_reg;
    reg [63:0] trips_reg;
    reg [63:0] step_reg;
    
    localparam [63:0] SCALE = 1000000000;
    localparam [63:0] ONE = 1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_high <= 64'd0;
            result_low <= 64'd0;
            dist_rem <= 64'd0;
            fuel_rem <= 64'd0;
            capacity <= 64'd0;
            n_reg <= 64'd0;
            trips_reg <= 64'd0;
            step_reg <= 64'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        dist_rem <= D_in * SCALE;
                        fuel_rem <= W_in * SCALE;
                        capacity <= C_in * SCALE;
                        
                        // Check if W <= C immediately
                        if (W_in <= C_in) begin
                            state <= FINAL_CALC;
                        end else begin
                            state <= CHECK_COND;
                        end
                    end
                end

                CHECK_COND: begin
                    // If fuel_rem <= capacity, go to final calc
                    if (fuel_rem <= capacity) begin
                        state <= FINAL_CALC;
                    end else begin
                        state <= CALC_N;
                    end
                end

                CALC_N: begin
                    // n = ceil(fuel_rem / capacity)
                    // n = (fuel_rem + capacity - 1) / capacity
                    n_reg <= (fuel_rem + capacity - ONE) / capacity;
                    state <= CALC_TRIPS;
                end

                CALC_TRIPS: begin
                    // trips = 2*n - 1
                    trips_reg <= (n_reg << 1) - ONE;
                    state <= CALC_STEP;
                end

                CALC_STEP: begin
                    // step = C / trips
                    // We need to check if step >= dist_rem to finish in one go
                    // step = capacity / trips_reg
                    step_reg <= capacity / trips_reg;
                    
                    // We need another state to compare because step might be large
                    state <= UPDATE_LOOP;
                end

                UPDATE_LOOP: begin
                    // Compare step_reg and dist_rem
                    if (step_reg >= dist_rem) begin
                        // We can reach the end in this segment
                        // Fuel consumed = dist_rem * trips_reg
                        // Delivered = fuel_rem - dist_rem * trips_reg
                        fuel_rem <= fuel_rem - (dist_rem * trips_reg);
                        dist_rem <= 64'd0;
                        state <= FINAL_CALC;
                    end else begin
                        // Advance by step_reg
                        dist_rem <= dist_rem - step_reg;
                        fuel_rem <= fuel_rem - capacity;
                        state <= CHECK_COND;
                    end
                end

                FINAL_CALC: begin
                    // This state handles both the W <= C case and the final segment of the loop
                    // fuel_rem is the remaining amount
                    // dist_rem is the remaining distance
                    // Result = max(0, fuel_rem - dist_rem)
                    if (fuel_rem > dist_rem) begin
                        fuel_rem <= fuel_rem - dist_rem;
                    end else begin
                        fuel_rem <= 64'd0;
                    end
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    // Output the result. 
                    // Since result is Q16.16 or similar, we need to scale back or output integer parts.
                    // The problem asks for 'maximum smoothie', likely a floating point or fixed point value.
                    // fuel_rem is now the delivered amount in scaled units (SCALE).
                    // We output high and low parts. For a 64-bit integer, this is straightforward.
                    result_high <= fuel_rem;
                    result_low <= 64'd0; // We can use lower bits for fractional part if needed, but fuel_rem is integer scaled.
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule