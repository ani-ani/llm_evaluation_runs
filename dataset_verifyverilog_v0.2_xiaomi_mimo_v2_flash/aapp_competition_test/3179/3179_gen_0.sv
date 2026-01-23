module canyon_map_solver (
    input clk,
    input rst_n,
    input start,
    input [15:0] poly_x [0:15],
    input [15:0] poly_y [0:15],
    input [3:0] num_vertices,
    input [1:0] k,
    output reg [31:0] result,
    output reg done
);

    // Fixed-point constants
    // Input format: Q12.4 (16 bits, 4 fractional)
    // Internal calculations use Q12.4 for coordinates to save space,
    // and Q32.32 (or 64-bit intermediates) for multiplications/divisions.
    // Output: Q16.16

    // State definitions
    localparam IDLE = 3'b000;
    localparam COMPUTE_BBOX = 3'b001;
    localparam DETERMINE_AXIS = 3'b010;
    localparam CALCULATE_SEGMENTS = 3'b011;
    localparam WAIT_DONE = 3'b100;
    localparam DONE_STATE = 3'b101;

    reg [2:0] state;
    reg [3:0] idx; // Vertex iterator
    reg [1:0] seg_idx; // Segment iterator

    // Bounding box registers (Q12.4)
    reg signed [15:0] min_x, max_x, min_y, max_y;
    
    // Intermediate registers
    reg signed [31:0] width_val, height_val; // Q12.4 + padding
    reg signed [31:0] span; // Q12.4
    reg signed [31:0] segment_size; // Q12.4
    reg signed [31:0] seg_start, seg_end; // Q12.4
    
    // Temporary registers for local bbox calculation
    reg signed [15:0] local_min_x, local_max_x, local_min_y, local_max_y;
    reg signed [31:0] local_w, local_h, local_max;
    
    // Result accumulator (max of segments)
    reg signed [31:0] max_segment_result; // Stored in Q12.4 initially
    
    // Division signals (iterative or combinatorial logic placeholder)
    // Since latency is ~200 cycles, we can use a simple state machine for division
    // or assume a single cycle LUT-based divider. Let's implement a small divider state.
    reg [5:0] div_count;
    reg signed [63:0] div_rem;
    reg signed [31:0] div_denom;
    reg signed [31:0] div_quotient;
    wire div_done;
    
    // Helper variables
    reg signed [31:0] temp_val;
    reg signed [63:0] temp_mul;

    // Divider Logic (Restoring division for 32-bit by 16-bit roughly)
    // We use a small counter to simulate a sequential divider or just unroll if space permits.
    // Given constraints, let's implement a simple iterative subtractor.
    // Actually, given 200 cycles budget, a simple state for division is safe.
    // Inputs: A (numer), B (denom). Output: A/B.
    // We'll compute division within CALCULATE_SEGMENTS using a separate mini-fsm or counter.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            idx <= 0;
            seg_idx <= 0;
            min_x <= 16'h7FFF; // Max positive
            max_x <= 16'h8000; // Max negative
            min_y <= 16'h7FFF;
            max_y <= 16'h8000;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start && num_vertices > 0) begin
                        state <= COMPUTE_BBOX;
                        idx <= 0;
                        min_x <= 16'h7FFF;
                        max_x <= 16'h8000;
                        min_y <= 16'h7FFF;
                        max_y <= 16'h8000;
                    end
                end

                COMPUTE_BBOX: begin
                    if (idx < num_vertices) begin
                        // Check X
                        if ($signed(poly_x[idx]) < $signed(min_x)) min_x <= poly_x[idx];
                        if ($signed(poly_x[idx]) > $signed(max_x)) max_x <= poly_x[idx];
                        // Check Y
                        if ($signed(poly_y[idx]) < $signed(min_y)) min_y <= poly_y[idx];
                        if ($signed(poly_y[idx]) > $signed(max_y)) max_y <= poly_y[idx];
                        idx <= idx + 1;
                    end else begin
                        state <= DETERMINE_AXIS;
                        idx <= 0;
                    end
                end

                DETERMINE_AXIS: begin
                    // Calculate width and height (Q12.4)
                    width_val <= max_x - min_x;
                    height_val <= max_y - min_y;
                    
                    if (k == 1) begin
                        state <= DONE_STATE;
                        // Result = max(width, height)
                        if ((max_x - min_x) > (max_y - min_y)) 
                            max_segment_result <= max_x - min_x;
                        else 
                            max_segment_result <= max_y - min_y;
                    end else begin
                        // Determine dominant axis
                        // If width >= height, dominant is X. Else Y.
                        // We store this info by simply checking the values later or saving a flag.
                        // Let's use the existing width_val/height_val registers as flags.
                        // If width_val > height_val, we use X axis logic. Else Y.
                        state <= CALCULATE_SEGMENTS;
                        seg_idx <= 0;
                        max_segment_result <= 32'h80000000; // -Infinity
                        
                        // Pre-calculate span for the loop
                        if (width_val > height_val) span <= width_val;
                        else span <= height_val;
                        
                        // Setup for Division: span / k
                        // k is 1, 2, or 3. 
                        // We will start a division process or calculate directly.
                        // Since k is small, we can do: segment_size = span / k;
                        // We will handle division in a sub-state or inline.
                    end
                end

                CALCULATE_SEGMENTS: begin
                    // We need to compute segment_size = span / k. 
                    // Since we are in a clocked process, we can do this.
                    // Actually, let's compute it once before entering the loop logic or inline.
                    // To save states, let's assume we can compute it or use a divider.
                    // If we want to be strictly sequential:
                    // We can calculate segment_size = span / k here.
                    // Let's use a simple divider logic. 
                    // Wait, `span` is Q12.4. `k` is integer.
                    // segment_size = span / k. (Shifted 4 bits right effectively).
                    
                    // Let's perform division using a loop if needed, but 200 cycles allows it.
                    // Optimization: Since k is small (2 or 3), we can just use a case statement.
                    // span is Q12.4. We want result in Q12.4.
                    // division = span / k.
                    
                    // Let's just calculate the segment range for the current seg_idx.
                    // Start = min + seg_idx * size
                    // End = Start + size
                    
                    // We need size first. 
                    // If we haven't calculated it yet (first cycle of this state):
                    if (seg_idx == 0 && div_count == 0) begin
                        // Calculate segment_size = span / k
                        // Manual division for k=2,3
                        if (k == 2) segment_size <= {1'b0, span[31:1]}; // Divide by 2
                        else if (k == 3) begin
                            // Divide by 3. Approximate or exact. 
                            // Since latency is high, let's do exact. 
                            // We'll use a counter to divide by 3.
                            div_rem <= span;
                            div_denom <= 3;
                            div_quotient <= 0;
                            div_count <= 32; // Max bits
                        end
                    end else if (div_count > 0) begin
                        // Iterative division by 3
                        div_rem <= (div_rem << 1) - (div_denom << 32); // This is hard in verilog without care.
                        // Let's do a simple subtractive division.
                        if (div_rem >= div_denom) begin
                            div_rem <= div_rem - div_denom;
                            div_quotient <= (div_quotient << 1) + 1;
                        end else begin
                            div_quotient <= div_quotient << 1;
                        end
                        div_count <= div_count - 1;
                    end else if (k == 3 && div_count == 0 && segment_size == 0) begin
                        // Latch result of division
                        segment_size <= div_quotient;
                    end
                    
                    // Once segment_size is ready (or if k=2, it's ready immediately):
                    // Wait for division to finish if k=3
                    if ((k==2 && seg_idx == 0) || (k==3 && segment_size != 0 && div_count == 0) || (seg_idx > 0)) begin
                        // We are ready to process a vertex for this segment
                        // Logic: Iterate all vertices, check if they fall in current segment range.
                        // Update local min/max for this segment.
                        
                        // To handle the loop efficiently inside the state machine:
                        // We use 'idx' to iterate vertices.
                        // We need to reset local min/max for the segment start.
                        
                        // We need to handle the segment iteration and vertex iteration.
                        // Structure: 
                        // Loop Segments (0 to k-1)
                        //   Reset Local Min/Max
                        //   Loop Vertices (0 to num_vertices-1)
                        //     Check if vertex in segment
                        //     Update Local Min/Max
                        //   Calculate Local Max(W, H)
                        //   Update Global Max Result
                        // End Loop
                        
                        // We need to manage 'seg_idx' and 'idx' carefully.
                        // Let's split the CALCULATE_SEGMENTS state into sub-logic.
                        
                        // --- Logic Start ---
                        
                        // First, ensure segment_size is valid.
                        // If we are here, and segment_size is valid (or k=2), proceed.
                        
                        // We need to calculate the bounds for the CURRENT segment.
                        // seg_start = min + seg_idx * segment_size
                        // seg_end = seg_start + segment_size
                        // But wait, what if dominant axis is Y? 
                        // We need to remember dominant axis from DETERMINE_AXIS.
                        // We can use width_val and height_val registers as flags or separate flag.
                        // Let's assume: if width_val > height_val, X is dominant.
                        // Let's use a temporary flag 'axis_is_x'.
                        reg axis_is_x;
                        axis_is_x = (width_val > height_val);
                        
                        // Calculate boundaries
                        reg signed [31:0] current_min, current_span;
                        if (axis_is_x) begin
                            current_min = min_x;
                            current_span = width_val;
                        end else begin
                            current_min = min_y;
                            current_span = height_val;
                        end
                        
                        // Segment bounds
                        reg signed [31:0] s_start, s_end;
                        s_start = current_min + (segment_size * seg_idx);
                        s_end = s_start + segment_size;
                        
                        // Handling vertex iteration for current segment
                        if (idx < num_vertices) begin
                            // Check if vertex 'idx' is within segment bounds
                            reg in_seg;
                            reg signed [15:0] val;
                            val = axis_is_x ? poly_x[idx] : poly_y[idx];
                            
                            // Inclusive/Exclusive? Usually we include touching boundaries.
                            // Check: val >= s_start && val < s_end (or <= s_end)
                            // Let's use: s_start <= val <= s_end
                            // Note: s_start/s_end are Q12.4, val is Q12.4.
                            
                            // We need to be careful with signed comparison of 32-bit vs 16-bit.
                            // val is 16-bit signed, s_start is 32-bit signed (expanded from 16-bit base).
                            
                            if ($signed(val) >= $signed(s_start[15:0]) && $signed(val) <= $signed(s_end[15:0])) begin
                                // In segment. Update local bbox.
                                if (idx == 0 || poly_x[idx] < local_min_x) local_min_x <= poly_x[idx];
                                if (idx == 0 || poly_x[idx] > local_max_x) local_max_x <= poly_x[idx];
                                if (idx == 0 || poly_y[idx] < local_min_y) local_min_y <= poly_y[idx];
                                if (idx == 0 || poly_y[idx] > local_max_y) local_max_y <= poly_y[idx];
                            end
                            idx <= idx + 1;
                        end else begin
                            // Done iterating vertices for this segment
                            // Calculate side length for this segment
                            // local_w = local_max_x - local_min_x
                            // local_h = local_max_y - local_min_y
                            // local_max = max(local_w, local_h)
                            
                            local_w <= local_max_x - local_min_x;
                            local_h <= local_max_y - local_min_y;
                            
                            // Use combinational logic to find max, or sequential
                            // Since we are in a clocked block, let's use a temp variable
                            if (local_max_x - local_min_x > local_max_y - local_min_y) 
                                local_max <= local_max_x - local_min_x;
                            else
                                local_max <= local_max_y - local_min_y;
                            
                            // Update global max result
                            // Note: If the segment is empty (no vertices inside), local_max might be garbage.
                            // We should only update if vertices were found. 
                            // Reset local_min/max to large values at segment start.
                            // Let's handle the reset of local registers properly.
                            // 
                            // We need to check if 'local_max' is valid. 
                            // If local_min_x > local_max_x, it's empty. 
                            // We initialize local_min/max at the start of the segment.
                            
                            // Wait, we need to detect segment start to reset local_min/max.
                            // We can do this when idx resets to 0 for a new segment.
                            
                            // Update Result
                            if (local_max > max_segment_result && local_min_x <= local_max_x) 
                                max_segment_result <= local_max;
                            
                            // Next Segment
                            seg_idx <= seg_idx + 1;
                            idx <= 0;
                            
                            // Reset local_min/max for next segment
                            local_min_x <= 16'h7FFF;
                            local_max_x <= 16'h8000;
                            local_min_y <= 16'h7FFF;
                            local_max_y <= 16'h8000;
                            
                            if (seg_idx == k - 1) begin
                                state <= DONE_STATE;
                            end
                        end
                    end
                end

                DONE_STATE: begin
                    // Convert Q12.4 to Q16.16
                    // Q12.4 value V. Q16.16 value = V << 12
                    result <= max_segment_result << 12;
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule