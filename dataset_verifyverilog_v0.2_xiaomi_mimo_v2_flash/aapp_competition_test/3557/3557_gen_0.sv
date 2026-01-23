module train_chaos(
    input clk,
    input rst_n,
    input start,
    input [2:0] p_in,
    input [2:0] idx_in,
    output reg [15:0] max_chaos,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam LOAD_PASSENGERS = 3'b001;
    localparam LOAD_ORDER = 3'b010;
    localparam BLOW_UP = 3'b011;
    localparam CALC_CHAOS = 3'b100;
    localparam UPDATE_MAX = 3'b101;
    localparam DONE = 3'b110;

    reg [2:0] state, next_state;
    
    // Arrays
    reg [2:0] p [0:7];      // Passenger counts
    reg [2:0] order [0:7];  // Explosion order indices (1-based)
    reg destroyed [0:7];    // Destruction status
    
    // Counters and indices
    reg [3:0] counter;      // Generic counter (0-8)
    reg [2:0] coach_idx;    // Coach index for operations
    
    // Chaos calculation variables
    reg [15:0] segment_sum;
    reg [15:0] current_chaos;
    reg [3:0] segment_count;
    reg [15:0] temp_sum;
    reg [2:0] start_c;      // Start of current segment
    reg found_passenger;
    reg in_segment;
    reg [2:0] i;

    // Next State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD_PASSENGERS;
            end
            LOAD_PASSENGERS: begin
                if (counter == 4'd8) next_state = LOAD_ORDER;
            end
            LOAD_ORDER: begin
                if (counter == 4'd8) next_state = BLOW_UP;
            end
            BLOW_UP: begin
                // We process one explosion per cycle iteration
                // BLOW_UP state handles marking destroyed
                next_state = CALC_CHAOS;
            end
            CALC_CHAOS: begin
                // Calculation takes multiple cycles (iterating coaches)
                // We use a micro-sequencing within the state
                // But simpler: transition when finished
                if (counter == 4'd9) next_state = UPDATE_MAX; // 9 indicates done with segments
            end
            UPDATE_MAX: begin
                if (coach_idx == 3'd7) next_state = DONE; // After 8 explosions (indices 0 to 7)
                else next_state = BLOW_UP;
            end
            DONE: begin
                if (start) next_state = DONE; // Hold done until start goes low? Or restart?
                else next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_chaos <= 16'd0;
            done <= 1'b0;
            counter <= 4'd0;
            coach_idx <= 3'd0;
            // Reset arrays/destroyed logic handled implicitly by load or reset
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    max_chaos <= 16'd0;
                    counter <= 4'd0;
                    coach_idx <= 3'd0;
                end

                LOAD_PASSENGERS: begin
                    if (counter < 4'd8) begin
                        p[counter[2:0]] <= p_in;
                        destroyed[counter[2:0]] <= 1'b0; // Init destroyed status
                        counter <= counter + 1'b1;
                    end
                end

                LOAD_ORDER: begin
                    if (counter < 4'd8) begin
                        // Store order, clamp to 1-8 if needed, but input is scaled 0-7 representing 1-8 usually
                        // Spec: idx_in is 1-based (scaled 0-7). 
                        // If input is 0, it might mean 1st coach or invalid. 
                        // Let's assume input 0 means index 1. 
                        // However, 'scaled 0-7' usually means 0 maps to 1, 7 maps to 8.
                        // We need to check if input 0 means 0-based or 1-based. Spec says '1-based'.
                        // If input is 0 (val), we need to convert to index 0 (array).
                        // Let's assume input 0 -> Coach 1 (Index 0). Input 7 -> Coach 8 (Index 7).
                        // Wait, spec says 'scaled 0-7'. If 1-based, input 0 is invalid for 1-based.
                        // Let's assume input value N corresponds to coach N+1.
                        // Example: p_in = 0 (val) -> Index 0. 
                        // Actually, let's handle the BLOW_UP logic to subtract 1 from idx_in.
                        // Here we just store the raw input to the order array.
                        order[counter[2:0]] <= idx_in;
                        counter <= counter + 1'b1;
                    end
                end

                BLOW_UP: begin
                    // Destroy the coach specified by current explosion step
                    // Explosion steps are 0 to 7. 
                    // We use 'coach_idx' to track which step we are on (0..7).
                    
                    // Convert 1-based index to 0-based array index
                    // Input 0 -> Coach 0. Input 7 -> Coach 7.
                    // But spec says 1-based. If input is 0 (scaled), it might mean 1st coach (index 0).
                    // Let's use (order[coach_idx] - 1) to be safe? 
                    // But if input is 'scaled 0-7', 0 usually maps to 0.
                    // Let's assume the input order[k] is ALREADY 0-indexed (i.e. 0 maps to coach 0).
                    // If it's truly 1-based, we subtract 1. 
                    // Let's stick to: Input 0 = Coach 0, Input 7 = Coach 7.
                    // Wait, "idx_in (1-based, scaled 0-7)" is contradictory. 
                    // Scaled 0-7 usually implies 0 to 7. 1-based implies 1 to 8.
                    // Likely mapping: Value 0 -> Coach 1 (Index 0). Value 7 -> Coach 8 (Index 7).
                    // So we do: Index = order[coach_idx]; 
                    // Actually, if 'scaled 0-7' means 'representing 0 to 7', it's 0-based.
                    // If '1-based', it's 1 to 8.
                    // Let's do: destroyed[idx_in_val] = 1. 
                    // If input is order[coach_idx], we need to map it.
                    // Let's use: destroyed[ order[coach_idx] ] = 1.
                    // This assumes order[k] is 0..7 and maps directly to array index.
                    // If input was truly 1..8, user would have sent 1..8. 
                    // Since input is [2:0], max 7. 
                    // I will assume input 0 maps to index 0.
                    
                    destroyed[order[coach_idx]] <= 1'b1;
                end

                CALC_CHAOS: begin
                    // This state calculates chaos for the CURRENT state (after explosion)
                    // We need to iterate through the array to find segments.
                    // We reuse 'counter' for the loop index.
                    
                    if (counter == 4'd0) begin
                        // Initialization for chaos calc
                        segment_sum <= 16'd0;
                        segment_count <= 4'd0;
                        found_passenger <= 1'b0;
                    end else if (counter <= 4'd8) begin
                        // We need to process indices 0..7. 
                        // But CALC_CHAOS enters with counter=0 (from previous state transition or logic).
                        // Let's refine: CALC_CHAOS iterates 0 to 8.
                        
                        // Actually, implementing segment finding in combinational logic or state is better.
                        // Since we don't have a clock inside the loop, we must do it in cycles.
                        // Let's implement a segment finder that takes 9 cycles (one for init, 8 for data).
                        
                        // If counter is 0, we are starting.
                        // Let's align counter properly.
                        
                        if (counter <= 4'd8) begin
                            // Process current coach i = counter - 1
                            i <= counter[2:0]; // Use a dedicated index register to avoid confusion
                            
                            // Logic: Traverse coaches 0..7
                            // If not destroyed and p > 0, add to sum.
                            // But wait, segments are CONNECTED components.
                            // Constraint: "When a coach is destroyed, it separates trains."
                            // So segments are contiguous blocks of existing coaches.
                            
                            // Micro-state inside CALC_CHAOS:
                            // We need to handle the segment traversal.
                            // Let's use 'start_c' to track start of segment.
                            // Let's use 'in_segment' flag.
                        end
                    end
                    
                    // To implement logic correctly, we break CALC_CHAOS into sub-cycles
                    // or use a combinational helper.
                    // Given the complexity, let's rely on a single loop state and simple logic.
                    
                    // SIMPLIFIED LOGIC for CALC_CHAOS:
                    // We will iterate 'counter' from 0 to 8.
                    // We use 'i' as the current coach index.
                    
                    if (counter < 4'd9) begin
                        // We will manually sequence the traversal inside this block
                        // using the 'i' register to walk through 0..7.
                        
                        // Note: This block executes every clock cycle.
                        // We need to make sure we capture segments correctly.
                        
                        if (counter == 4'd0) begin
                            // Reset calc vars
                            current_chaos <= 16'd0;
                            segment_count <= 4'd0;
                            i <= 3'd0;
                            temp_sum <= 16'd0;
                            in_segment <= 1'b0;
                        end else begin
                            // Process coach i
                            if (i < 3'd8) begin
                                if (!destroyed[i]) begin
                                    // Coach exists
                                    if (p[i] > 0) begin
                                        // Add to temp_sum (value is 0 or 10 in scaled)
                                        // Spec: Chaos = 0 if 0, 10 if >0.
                                        // p[i] is 0..7. So if >0, chaos is 10.
                                        temp_sum <= temp_sum + 16'd10;
                                        in_segment <= 1'b1;
                                    end
                                    // If p[i] == 0, it still belongs to segment (empty car in train)
                                    // Spec says: "sum of segment chaoses".
                                    // Chaos of a segment is based on total passengers.
                                    // If sum > 0 -> 10. If sum == 0 -> 0.
                                    // So we accumulate passengers first? No.
                                    // Wait. "Chaos of a segment = ceil(total_passengers / 10) * 10"
                                    // Then: "Scaled: Chaos = ceil(passengers / 10) * 10. Since passengers <= 7, chaos is 0 if 0, 10 otherwise."
                                    // This implies we sum the passengers of the segment, THEN check if >0.
                                    // BUT. "Sum all segment chaoses".
                                    // If we have a segment with passengers 3 and 4. Total 7. 
                                    // If we apply rule per coach: 10 + 10 = 20. 
                                    // If we apply rule per segment (sum 7 -> 10). 
                                    // The description "Sum of segment chaoses" and "chaos is 0 if 0, 10 otherwise" implies per segment.
                                    // So we need to sum passengers in a segment first, then apply 10 if >0.
                                    
                                    // Accumulate passengers in the segment
                                    // Wait, if p[i] is 0 (passenger count), chaos is 0.
                                    // But we need to accumulate passengers first.
                                    // However, p[i] is 'passenger count' (0-7).
                                    // If p[i] is 0, it contributes 0 to passenger sum.
                                    // So we accumulate p[i].
                                    temp_sum <= temp_sum + p[i];
                                    in_segment <= 1'b1;
                                end else begin
                                    // Coach destroyed
                                    // End of segment
                                    if (in_segment) begin
                                        if (temp_sum > 0) current_chaos <= current_chaos + 16'd10;
                                        segment_count <= segment_count + 1'b1;
                                        temp_sum <= 16'd0;
                                        in_segment <= 1'b0;
                                    end
                                end
                            end else if (i == 3'd8) begin
                                // Finish last segment
                                if (in_segment) begin
                                    if (temp_sum > 0) current_chaos <= current_chaos + 16'd10;
                                    segment_count <= segment_count + 1'b1;
                                end
                            end
                            
                            i <= i + 1'b1;
                        end
                        
                        // Increment counter to track cycles
                        if (counter < 4'd9) counter <= counter + 1'b1;
                    end
                end

                UPDATE_MAX: begin
                    // Total Chaos = current_chaos * segment_count
                    // We need to handle the multiplication.
                    // Max 8 segments * 10 = 80. Fits in small logic.
                    // Use a temp variable for calculation.
                    
                    // current_chaos is sum of 10s (one 10 per segment with passengers).
                    // Wait, in CALC_CHAOS we did: current_chaos <= current_chaos + 16'd10;
                    // So current_chaos is already (segments_with_passengers * 10).
                    // Then we multiply by total_segments.
                    // Spec: "Total chaos = (sum of segment chaoses) * (number of segments)"
                    // "Chaos of segment = 0 or 10". So Sum = N_passenger_segments * 10.
                    // Total = (N_passenger_segments * 10) * N_total_segments.
                    // N_total_segments = segment_count (calculated in CALC_CHAOS).
                    
                    // Multiplication: current_chaos * segment_count
                    // current_chaos is max 80. segment_count max 8. Result max 640.
                    
                    if (current_chaos * segment_count > max_chaos) begin
                        max_chaos <= current_chaos * segment_count;
                    end
                    
                    // Advance explosion step
                    coach_idx <= coach_idx + 1'b1;
                    
                    // Reset counter for next BLOW_UP / CALC_CHAOS cycle
                    counter <= 4'd0;
                end

                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule

// Since CALC_CHAOS logic is complex for a single state, we might need to break it down more.
// The provided code tries to do everything in CALC_CHAOS using 'counter' and 'i'.
// However, the 'always @' block inside CALC_CHAOS is sequential.
// Let's refine the CALC_CHAOS logic to ensure it correctly calculates segments.

// Correction on CALC_CHAOS logic:
// The previous logic had a loop inside the state block. 
// We need to ensure 'i' increments correctly. 
// Also, the multiplication in UPDATE_MAX needs to be done carefully.

// Let's rewrite the core logic blocks for clarity and correctness.

module train_chaos_v2 (
    input clk,
    input rst_n,
    input start,
    input [2:0] p_in,
    input [2:0] idx_in,
    output reg [15:0] max_chaos,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam LOAD_PASSENGERS = 3'b001;
    localparam LOAD_ORDER = 3'b010;
    localparam BLOW_UP = 3'b011;
    localparam CALC_CHAOS = 3'b100;
    localparam UPDATE_MAX = 3'b101;
    localparam DONE = 3'b110;

    reg [2:0] state, next_state;
    
    reg [2:0] p [0:7];
    reg [2:0] order [0:7];
    reg destroyed [0:7];
    
    reg [3:0] counter; // Used for loading and chaos calculation iteration
    reg [2:0] coach_idx; // Tracks explosion step (0..7)
    
    // Calculation variables
    reg [15:0] current_chaos_acc; // Accumulates segment chaoses (10s)
    reg [3:0] segment_count_acc;  // Counts total segments
    reg [15:0] passenger_sum;     // Sum of passengers in current segment
    reg [2:0] i_idx;              // Index for traversing coaches
    reg in_seg;                   // Flag if we are in a segment
    
    // Next State
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = LOAD_PASSENGERS;
            LOAD_PASSENGERS: if (counter == 4'd8) next_state = LOAD_ORDER;
            LOAD_ORDER: if (counter == 4'd8) next_state = BLOW_UP;
            BLOW_UP: next_state = CALC_CHAOS;
            CALC_CHAOS: if (i_idx == 3'd8 && !in_seg) next_state = UPDATE_MAX; 
                        // Wait, i_idx goes 0..8. Need to finish processing.
                        // Simplified: We run CALC_CHAOS for 10 cycles (0..9).
                        // Actually, let's use 'counter' for CALC_CHAOS cycle count.
                        // If counter > 8, we are done.
            UPDATE_MAX: begin
                if (coach_idx == 3'd7) next_state = DONE;
                else next_state = BLOW_UP;
            end
            DONE: if (!start) next_state = IDLE; else next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

    // Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_chaos <= 16'd0;
            done <= 1'b0;
            counter <= 4'd0;
            coach_idx <= 3'd0;
            i_idx <= 3'd0;
            in_seg <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    max_chaos <= 16'd0;
                    coach_idx <= 3'd0;
                    counter <= 4'd0;
                end

                LOAD_PASSENGERS: begin
                    if (counter < 4'd8) begin
                        p[counter[2:0]] <= p_in;
                        destroyed[counter[2:0]] <= 1'b0;
                        counter <= counter + 1'b1;
                    end
                end

                LOAD_ORDER: begin
                    if (counter < 4'd8) begin
                        // Store order. Assumption: Input is 0-7 mapped to Coach 0-7.
                        // If 1-based (1-8), we would subtract 1 here.
                        // Let's check Spec: "idx_in (1-based, scaled 0-7)".
                        // This is confusing. Usually "scaled 0-7" means values 0..7.
                        // "1-based" means it refers to coach 1..8.
                        // So Input 0 -> Coach 1 (Index 0). Input 7 -> Coach 8 (Index 7).
                        // Thus we DO NOT subtract 1, we assume input is already array index? 
                        // No, if input is '1-based', input 1 is valid? Range is 0-7.
                        // If range is 0-7, and it's 1-based, then 0 is invalid or represents 1.
                        // Given [2:0] range 0-7, it's likely 0 maps to 0, 1 to 1...
                        // But let's be safe. If input is 0, it destroys Coach 0.
                        // If input is 7, it destroys Coach 7.
                        order[counter[2:0]] <= idx_in;
                        counter <= counter + 1'b1;
                    end
                end

                BLOW_UP: begin
                    // Destroy coach
                    // Use order[coach_idx] as index.
                    destroyed[order[coach_idx]] <= 1'b1;
                end

                CALC_CHAOS: begin
                    // We iterate 0 to 8. 
                    // Let's use a separate state counter for this phase to avoid conflict with LOAD counter.
                    // Actually, we can reuse 'counter' but we must reset it before entering or use 'i_idx'.
                    // Let's use 'i_idx' as the traversal index.
                    
                    if (counter == 4'd0) begin
                        // Init
                        current_chaos_acc <= 16'd0;
                        segment_count_acc <= 4'd0;
                        passenger_sum <= 16'd0;
                        i_idx <= 3'd0;
                        in_seg <= 1'b0;
                        counter <= 4'd1; // Mark that we started
                    end else begin
                        // Process coach i_idx
                        if (i_idx < 3'd8) begin
                            if (!destroyed[i_idx]) begin
                                // Add passengers
                                passenger_sum <= passenger_sum + p[i_idx];
                                in_seg <= 1'b1;
                            end else begin
                                // Boundary: End of segment
                                if (in_seg) begin
                                    if (passenger_sum > 0) current_chaos_acc <= current_chaos_acc + 16'd10;
                                    segment_count_acc <= segment_count_acc + 1'b1;
                                end
                                passenger_sum <= 16'd0;
                                in_seg <= 1'b0;
                            end
                        end else begin
                            // i_idx == 8 (end of array)
                            if (in_seg) begin
                                if (passenger_sum > 0) current_chaos_acc <= current_chaos_acc + 16'd10;
                                segment_count_acc <= segment_count_acc + 1'b1;
                            end
                            in_seg <= 1'b0; // Ensure we fall through to DONE condition
                        end
                        
                        i_idx <= i_idx + 1'b1;
                    end
                end

                UPDATE_MAX: begin
                    // Reset counter for next load/calc cycle if needed
                    counter <= 4'd0;
                    
                    // Calculate Total Chaos: (Sum of Segment Chaoses) * Number of Segments
                    // current_chaos_acc is sum of 10s (0, 10, 20, ...)
                    // segment_count_acc is 1..8
                    // Logic: current_chaos_acc * segment_count_acc
                    
                    if (current_chaos_acc * segment_count_acc > max_chaos) begin
                        max_chaos <= current_chaos_acc * segment_count_acc;
                    end
                    
                    coach_idx <= coach_idx + 1'b1;
                end

                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule

// To ensure robustness, let's add a tiny FSM for the CALC_CHAOS loop to be explicit.
// But the current implementation with 'i_idx' is standard.
// Let's clean up the response to be one cohesive module.

// Final check on state transitions for CALC_CHAOS.
// In CALC_CHAOS, we go: 
// Cycle 0: Init (i_idx=0).
// Cycle 1: Process 0. i_idx=1.
// ...
// Cycle 8: Process 7. i_idx=8.
// Cycle 9: Process i_idx=8 (boundary check). i_idx=9.
// We need to detect end of processing.

// Modification: In CALC_CHAOS, exit when i_idx > 3'd8.
// Transition: if (i_idx > 3'd8) next_state = UPDATE_MAX;

module train_chaos_final(
    input clk,
    input rst_n,
    input start,
    input [2:0] p_in,
    input [2:0] idx_in,
    output reg [15:0] max_chaos,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam LOAD_PASSENGERS = 3'b001;
    localparam LOAD_ORDER = 3'b010;
    localparam BLOW_UP = 3'b011;
    localparam CALC_CHAOS = 3'b100;
    localparam UPDATE_MAX = 3'b101;
    localparam DONE = 3'b110;

    reg [2:0] state, next_state;
    
    reg [2:0] p [0:7];
    reg [2:0] order [0:7];
    reg destroyed [0:7];
    
    reg [3:0] counter;
    reg [2:0] coach_idx;
    
    // Calculation variables
    reg [15:0] current_chaos_acc;
    reg [3:0] segment_count_acc;
    reg [15:0] passenger_sum;
    reg [2:0] i_idx;
    reg in_seg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = LOAD_PASSENGERS;
            LOAD_PASSENGERS: if (counter == 4'd8) next_state = LOAD_ORDER;
            LOAD_ORDER: if (counter == 4'd8) next_state = BLOW_UP;
            BLOW_UP: next_state = CALC_CHAOS;
            CALC_CHAOS: if (i_idx > 3'd8) next_state = UPDATE_MAX;
            UPDATE_MAX: next_state = (coach_idx == 3'd7) ? DONE : BLOW_UP;
            DONE: if (!start) next_state = IDLE; else next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_chaos <= 16'd0;
            done <= 1'b0;
            counter <= 4'd0;
            coach_idx <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    max_chaos <= 16'd0;
                    coach_idx <= 3'd0;
                    counter <= 4'd0;
                end

                LOAD_PASSENGERS: begin
                    if (counter < 4'd8) begin
                        p[counter[2:0]] <= p_in;
                        destroyed[counter[2:0]] <= 1'b0;
                        counter <= counter + 1'b1;
                    end
                end

                LOAD_ORDER: begin
                    if (counter < 4'd8) begin
                        order[counter[2:0]] <= idx_in;
                        counter <= counter + 1'b1;
                    end
                end

                BLOW_UP: begin
                    // Destruction. Assumption: input order value is the array index.
                    destroyed[order[coach_idx]] <= 1'b1;
                    // Prepare for CALC_CHAOS
                    counter <= 4'd0; // Reset helper counter
                    i_idx <= 3'd0;
                end

                CALC_CHAOS: begin
                    if (counter == 4'd0) begin
                        // Init calc registers
                        current_chaos_acc <= 16'd0;
                        segment_count_acc <= 4'd0;
                        passenger_sum <= 16'd0;
                        in_seg <= 1'b0;
                        counter <= 4'd1;
                        // i_idx is 0, start processing
                    end else begin
                        // Processing Loop
                        if (i_idx < 3'd8) begin
                            if (!destroyed[i_idx]) begin
                                passenger_sum <= passenger_sum + p[i_idx];
                                in_seg <= 1'b1;
                            end else begin
                                // Destroyed coach ends current segment if one exists
                                if (in_seg) begin
                                    if (passenger_sum > 0) current_chaos_acc <= current_chaos_acc + 16'd10;
                                    segment_count_acc <= segment_count_acc + 1'b1;
                                    passenger_sum <= 16'd0;
                                    in_seg <= 1'b0;
                                end
                            end
                        end else begin
                            // Post-loop cleanup for the last segment
                            if (in_seg) begin
                                if (passenger_sum > 0) current_chaos_acc <= current_chaos_acc + 16'd10;
                                segment_count_acc <= segment_count_acc + 1'b1;
                            end
                        end
                        i_idx <= i_idx + 1'b1;
                    end
                end

                UPDATE_MAX: begin
                    // Multiply. current_chaos_acc is sum of 10s. 
                    // Total = current_chaos_acc * segment_count_acc
                    if (current_chaos_acc * segment_count_acc > max_chaos) begin
                        max_chaos <= current_chaos_acc * segment_count_acc;
                    end
                    coach_idx <= coach_idx + 1'b1;
                end

                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule