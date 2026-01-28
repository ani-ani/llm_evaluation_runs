module ToyAssignment(
    input clk,
    input rst_n,
    input start,
    input [31:0] event_data,
    input event_valid,
    input event_done,
    output reg [15:0] result,
    output reg done,
    output reg ready
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INPUT_PHASE = 3'd1;
    localparam [2:0] COMPUTE    = 3'd2;
    localparam [2:0] MATCHING   = 3'd3;
    localparam [2:0] OUTPUT     = 3'd4;
    localparam [2:0] FINISH     = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] cycle_count;  // 0-15 for event buffer index
    reg [3:0] process_count;  // For iterating through kids/toys
    reg [3:0] kid_idx, toy_idx, kid2_idx, toy2_idx;
    reg [3:0] i, j, k;
    
    // Event buffer: 16 slots of 24-bit (s[15:0], k[3:0], t[3:0])
    reg [23:0] event_buffer [0:15];  // Use packed format
    reg [3:0] event_count;
    
    // History matrix: [kid][toy] -> {duration[15:0], first_start[15:0]}
    reg [31:0] history [0:15][0:15];  // 16 kids x 16 toys
    
    // Preference order: [kid][rank] -> toy index
    reg [3:0] preference [0:15][0:15];  // 16 kids, 16 toys ranked
    
    // Envy matrix: for each toy, track max duration and who has it
    reg [15:0] toy_max_duration [0:15];  // Max duration per toy
    reg [15:0] toy_max_kid [0:15];       // Kid with max duration (bitmask)
    
    // Validity matrix: [kid][toy] -> 1 if assignment is valid
    reg valid_matrix [0:15][0:15];
    
    // Matching state
    reg [15:0] assigned_toys;  // Bitmask of assigned toys
    reg [3:0] matched_toys [0:15];  // Kid -> assigned toy
    reg matching_done;
    reg [3:0] match_kid;
    reg [3:0] match_toy;
    reg [3:0] backtrack_count;
    
    // Temporary signals
    reg [15:0] temp_s;
    reg [3:0] temp_k, temp_t;
    reg [15:0] dur1, dur2;
    reg [15:0] start1, start2;
    reg valid_flag;
    reg [15:0] bitmask;
    reg [3:0] temp_idx;
    reg [7:0] result_temp;
    reg [15:0] cycle_max;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            ready <= 1'b1;
            cycle_count <= 4'd0;
            process_count <= 4'd0;
            event_count <= 4'd0;
            match_kid <= 4'd0;
            match_toy <= 4'd0;
            assigned_toys <= 16'd0;
            matching_done <= 1'b0;
            cycle_max <= 16'd1000;
            
            // Initialize all arrays
            for (i = 0; i < 16; i = i + 1) begin
                event_buffer[i] <= 24'd0;
                toy_max_duration[i] <= 16'd0;
                toy_max_kid[i] <= 16'd0;
                matched_toys[i] <= 4'd15;  // Initialize to invalid
                for (j = 0; j < 16; j = j + 1) begin
                    history[i][j] <= 32'd0;
                    valid_matrix[i][j] <= 1'b0;
                    preference[i][j] <= 4'd15;
                end
            end
        end else begin
            state <= next_state;
            
            // FSM Operations
            case (state)
                IDLE: begin
                    if (start) begin
                        ready <= 1'b0;
                        done <= 1'b0;
                        event_count <= 4'd0;
                        cycle_count <= 4'd0;
                    end
                end
                
                INPUT_PHASE: begin
                    if (event_valid && cycle_count < 16) begin
                        // Extract and store event: s[15:0], k[3:0], t[3:0]
                        event_buffer[cycle_count] <= event_data[23:0];
                        event_count <= event_count + 4'd1;
                        cycle_count <= cycle_count + 4'd1;
                    end
                end
                
                COMPUTE: begin
                    case (process_count)
                        0: begin  // Process events into history
                            if (cycle_count < event_count) begin
                                temp_s <= event_buffer[cycle_count][15:0];
                                temp_k <= event_buffer[cycle_count][19:16];
                                temp_t <= event_buffer[cycle_count][23:20];
                                process_count <= 4'd1;
                            end
                        end
                        1: begin
                            // Update duration and first start
                            dur1 <= history[temp_k][temp_t][31:16];
                            start1 <= history[temp_k][temp_t][15:0];
                            process_count <= 4'd2;
                        end
                        2: begin
                            // Add duration, update first start if earlier
                            if (start1 == 16'd0 || temp_s < start1) begin
                                history[temp_k][temp_t] <= {dur1 + 16'd1, temp_s};
                            end else begin
                                history[temp_k][temp_t] <= {dur1 + 16'd1, start1};
                            end
                            cycle_count <= cycle_count + 4'd1;
                            process_count <= 4'd0;
                        end
                        3: begin  // Build preference order for each kid
                            kid_idx <= cycle_count;
                            toy_idx <= 4'd0;
                            process_count <= 4'd4;
                        end
                        4: begin
                            // Find earliest start for remaining toys
                            temp_s <= 16'hFFFF;
                            temp_t <= 4'd15;
                            toy2_idx <= 4'd0;
                            process_count <= 4'd5;
                        end
                        5: begin
                            if (toy2_idx < 16) begin
                                start2 <= history[kid_idx][toy2_idx][15:0];
                                process_count <= 4'd6;
                            end else begin
                                // Store found toy
                                preference[kid_idx][toy_idx] <= temp_t;
                                toy_idx <= toy_idx + 4'd1;
                                process_count <= 4'd4;
                            end
                        end
                        6: begin
                            // Check if this toy is better
                            if (start2 < temp_s && start2 != 16'd0) begin
                                temp_s <= start2;
                                temp_t <= toy2_idx;
                            end
                            toy2_idx <= toy2_idx + 4'd1;
                            process_count <= 4'd5;
                        end
                        7: begin  // Compute toy max durations
                            toy_idx <= cycle_count;
                            dur1 <= 16'd0;
                            kid_idx <= 4'd0;
                            process_count <= 4'd8;
                        end
                        8: begin
                            if (kid_idx < 16) begin
                                dur2 <= history[kid_idx][toy_idx][31:16];
                                process_count <= 4'd9;
                            end else begin
                                toy_max_duration[toy_idx] <= dur1;
                                cycle_count <= cycle_count + 4'd1;
                                process_count <= 4'd7;
                            end
                        end
                        9: begin
                            if (dur2 == dur1 && dur1 != 16'd0) begin
                                toy_max_kid[toy_idx] <= toy_max_kid[toy_idx] | (16'd1 << kid_idx);
                            end else if (dur2 > dur1) begin
                                dur1 <= dur2;
                                toy_max_kid[toy_idx] <= (16'd1 << kid_idx);
                            end
                            kid_idx <= kid_idx + 4'd1;
                            process_count <= 4'd8;
                        end
                        10: begin  // Build validity matrix
                            kid_idx <= cycle_count;
                            toy_idx <= 4'd0;
                            process_count <= 4'd11;
                        end
                        11: begin
                            // Check if this (kid, toy) assignment is valid
                            kid2_idx <= 4'd0;
                            valid_flag <= 1'b1;
                            process_count <= 4'd12;
                        end
                        12: begin
                            if (kid2_idx < 16 && kid2_idx != kid_idx) begin
                                // Check if kid2 has a toy assigned in this scenario
                                // We need to check all other toys that kid2 prefers over toy_idx
                                toy2_idx <= 4'd0;
                                process_count <= 4'd13;
                            end else begin
                                valid_matrix[kid_idx][toy_idx] <= valid_flag;
                                toy_idx <= toy_idx + 4'd1;
                                process_count <= 4'd11;
                            end
                        end
                        13: begin
                            if (toy2_idx < 16) begin
                                // Check if kid2 prefers toy2 over toy_idx
                                // Find rank of toy_idx for kid2
                                i <= 4'd0;
                                j <= 4'd0;
                                process_count <= 4'd14;
                            end else begin
                                kid2_idx <= kid2_idx + 4'd1;
                                process_count <= 4'd12;
                            end
                        end
                        14: begin
                            if (i < 16) begin
                                if (preference[kid2_idx][i] == toy2_idx) begin
                                    j <= i;
                                end
                                i <= i + 4'd1;
                                process_count <= 4'd14;
                            end else begin
                                // Find rank of toy_idx
                                i <= 4'd0;
                                process_count <= 4'd15;
                            end
                        end
                        15: begin
                            if (i < 16 && preference[kid2_idx][i] != toy_idx) begin
                                i <= i + 4'd1;
                                process_count <= 4'd15;
                            end else if (i < 16) begin
                                // j is rank of toy2, i is rank of toy_idx
                                // If toy2 is better (lower rank) AND kid envies for toy2
                                if (j < i) begin
                                    // Check envy: kid envies kid2 for toy2 if
                                    // kid2's duration > kid's duration for toy2
                                    dur1 <= history[kid_idx][toy2_idx][31:16];
                                    dur2 <= history[kid2_idx][toy2_idx][31:16];
                                    process_count <= 4'd16;
                                end else begin
                                    toy2_idx <= toy2_idx + 4'd1;
                                    process_count <= 4'd13;
                                end
                            end else begin
                                toy2_idx <= toy2_idx + 4'd1;
                                process_count <= 4'd13;
                            end
                        end
                        16: begin
                            // Check if kid envies kid2 for toy2
                            if (dur2 > dur1 && dur1 != 16'd0) begin
                                valid_flag <= 1'b0;
                            end
                            toy2_idx <= toy2_idx + 4'd1;
                            process_count <= 4'd13;
                        end
                        default: process_count <= 4'd0;
                    endcase
                end
                
                MATCHING: begin
                    if (!matching_done) begin
                        if (match_kid < 16) begin
                            // Try to find a toy for this kid
                            match_toy <= 4'd0;
                            process_count <= 4'd20;
                        end else begin
                            matching_done <= 1'b1;
                        end
                    end
                end
                
                OUTPUT: begin
                    // Pack result
                    result_temp <= 8'd0;
                    process_count <= 4'd0;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    ready <= 1'b1;
                end
            endcase
            
            // Special handling for MATCHING state transitions
            if (state == MATCHING && process_count == 4'd20) begin
                if (match_toy < 16) begin
                    // Check if toy is available and assignment is valid
                    if (!(assigned_toys & (16'd1 << match_toy)) && valid_matrix[match_kid][match_toy]) begin
                        // Assign
                        assigned_toys <= assigned_toys | (16'd1 << match_toy);
                        matched_toys[match_kid] <= match_toy;
                        match_kid <= match_kid + 4'd1;
                        process_count <= 4'd0;
                    end else begin
                        match_toy <= match_toy + 4'd1;
                    end
                end else begin
                    // No valid toy found, backtrack
                    if (match_kid > 0) begin
                        match_kid <= match_kid - 4'd1;
                        temp_idx <= matched_toys[match_kid - 4'd1];
                        assigned_toys <= assigned_toys & ~(16'd1 << matched_toys[match_kid - 4'd1]);
                        matched_toys[match_kid - 4'd1] <= 4'd15;
                        match_toy <= matched_toys[match_kid - 4'd1] + 4'd1;
                        process_count <= 4'd20;
                    end else begin
                        // No solution
                        result <= 16'hFFFF;
                        matching_done <= 1'b1;
                    end
                end
            end
            
            // Output packing
            if (state == OUTPUT) begin
                result_temp <= result_temp + 8'd1;
                if (result_temp < 16) begin
                    if (matched_toys[result_temp] != 4'd15) begin
                        result[result_temp*1 + 3: result_temp*1] <= matched_toys[result_temp];
                    end
                end else begin
                    next_state <= FINISH;
                end
            end
            
            // Cycle counter for timeout
            if (state != IDLE && state != FINISH) begin
                cycle_max <= cycle_max - 16'd1;
            end
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INPUT_PHASE;
            end
            INPUT_PHASE: begin
                if (event_done || cycle_count >= 16) next_state = COMPUTE;
            end
            COMPUTE: begin
                // Progress through compute phases
                if (process_count == 0 && cycle_count >= event_count && cycle_count >= 16) begin
                    next_state = MATCHING;
                end
            end
            MATCHING: begin
                if (matching_done) next_state = OUTPUT;
            end
            OUTPUT: begin
                if (result_temp >= 16 || process_count >= 10) next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Timeout check
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // handled in main FSM
        end else if (cycle_max == 16'd0 && state != IDLE && state != FINISH) begin
            // Timeout: set result to 0xFFFF (impossible)
            result <= 16'hFFFF;
            next_state <= OUTPUT;
        end
    end
    
endmodule