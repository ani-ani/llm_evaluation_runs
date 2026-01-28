module rain_optimizer (
    input clk,
    input rst_n,
    input start,
    input [7:0] d,  // Distance (0-16m)
    input [7:0] t,  // Time limit (0-16s)
    input [7:0] c,  // Number of clouds (0-8)
    input [7:0] r,  // Number of roofs (0-4)
    // Cloud data: 8 clouds, each with start time, end time, probability, intensity
    input [7:0] cloud_start [0:7],
    input [7:0] cloud_end [0:7],
    input [15:0] cloud_prob [0:7],  // Q8.8 fixed point
    input [7:0] cloud_intensity [0:7],
    // Roof data: 4 roofs, each with start and end position
    input [7:0] roof_start [0:3],
    input [7:0] roof_end [0:3],
    output reg [31:0] result,  // Q16.16 fixed point
    output reg done
);

// State definitions
localparam [2:0] IDLE       = 3'd0;
localparam [2:0] COMPUTE_E  = 3'd1;
localparam [2:0] DP_INIT    = 3'd2;
localparam [2:0] DP_COMPUTE = 3'd3;
localparam [2:0] FINISHED   = 3'd4;

// Registers for state machine
reg [2:0] state, next_state;
reg [7:0] time_idx, pos_idx;
reg [7:0] cloud_idx;

// Arrays - must be declared as reg
reg [31:0] dp_next [0:16];  // Q16.16
reg [31:0] dp_curr [0:16];  // Q16.16
reg [31:0] E [0:16];  // Expected rain at each time (Q16.16)
reg [15:0] roof_mask [0:16];  // Bitmask: bit=1 if position is under roof

// Cycle counter to prevent infinite loops
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd200;

// Helper function for min
function [31:0] min_f;
    input [31:0] a, b;
    begin
        min_f = (a < b) ? a : b;
    end
endfunction

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: if (start) next_state = COMPUTE_E;
        COMPUTE_E: if (cloud_idx >= c || cloud_idx >= 8'd8) next_state = DP_INIT;
        DP_INIT: next_state = DP_COMPUTE;
        DP_COMPUTE: begin
            if (time_idx == 8'd0 && pos_idx == 8'd0) begin
                next_state = FINISHED;
            end else if (cycle_count >= MAX_CYCLES) begin
                next_state = FINISHED;  // Safety timeout
            end
        end
        FINISHED: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

// Main computation
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        done <= 1'b0;
        result <= 32'd0;
        cloud_idx <= 8'd0;
        time_idx <= 8'd0;
        pos_idx <= 8'd0;
        cycle_count <= 8'd0;
        // Initialize all arrays
        for (integer i = 0; i < 16; i = i + 1) begin
            E[i] <= 32'd0;
            dp_next[i] <= 32'h7FFFFFFF;  // Infinity (large value)
            dp_curr[i] <= 32'h7FFFFFFF;
            roof_mask[i] <= 16'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                cloud_idx <= 8'd0;
                time_idx <= 8'd0;
                pos_idx <= 8'd0;
                cycle_count <= 8'd0;
                // Reset E array
                for (integer i = 0; i < 16; i = i + 1) begin
                    E[i] <= 32'd0;
                end
            end
            
            COMPUTE_E: begin
                // Compute expected rain for each time step
                if (cloud_idx < c && cloud_idx < 8'd8) begin
                    for (integer tm = 0; tm < 16; tm = tm + 1) begin
                        if (tm >= cloud_start[cloud_idx] && tm < cloud_end[cloud_idx]) begin
                            // E[tm] += p_i * a_i (Q8.8 * integer = Q8.8, then shift to Q16.16)
                            // Multiply by 256 (<<8) to convert Q8.8 to Q16.16
                            E[tm] <= E[tm] + (cloud_prob[cloud_idx] * cloud_intensity[cloud_idx]);
                        end
                    end
                    cloud_idx <= cloud_idx + 8'd1;
                end
            end
            
            DP_INIT: begin
                // Initialize DP: at position d at any time, rain = 0
                for (integer i = 0; i < 16; i = i + 1) begin
                    if (i <= d) begin
                        dp_next[i] <= 32'd0;
                    end else begin
                        dp_next[i] <= 32'h7FFFFFFF;
                    end
                end
                // Initialize roof_mask
                for (integer i = 0; i < 16; i = i + 1) begin
                    roof_mask[i] <= 16'd0;
                end
                // Mark covered positions
                for (integer j = 0; j < 4; j = j + 1) begin
                    if (j < r) begin
                        for (integer k = 0; k < 16; k = k + 1) begin
                            if (k >= roof_start[j] && k < roof_end[j]) begin
                                roof_mask[k] <= 1'b1;
                            end
                        end
                    end
                end
                time_idx <= (t > 8'd0) ? t - 8'd1 : 8'd0;
                pos_idx <= (d > 8'd0) ? d - 8'd1 : 8'd0;
            end
            
            DP_COMPUTE: begin
                cycle_count <= cycle_count + 8'd1;
                
                if (time_idx > 8'd0) begin
                    // Option 1: Wait (if under roof)
                    if (roof_mask[pos_idx] && pos_idx <= d) begin
                        dp_curr[pos_idx] <= min_f(dp_curr[pos_idx], dp_next[pos_idx]);
                    end
                    
                    // Option 2: Move
                    if (pos_idx < d) begin
                        // Rain during movement: E[time_idx] if not under roof
                        if (!roof_mask[pos_idx]) begin
                            dp_curr[pos_idx] <= min_f(dp_curr[pos_idx], dp_next[pos_idx + 8'd1] + E[time_idx]);
                        end else begin
                            dp_curr[pos_idx] <= min_f(dp_curr[pos_idx], dp_next[pos_idx + 8'd1]);
                        end
                    end
                    
                    // Update indices
                    if (pos_idx == 8'd0) begin
                        // Finished this time step - copy dp_curr to dp_next
                        for (integer i = 0; i < 16; i = i + 1) begin
                            dp_next[i] <= dp_curr[i];
                            dp_curr[i] <= 32'h7FFFFFFF;
                        end
                        time_idx <= time_idx - 8'd1;
                        pos_idx <= (d > 8'd0) ? d - 8'd1 : 8'd0;
                    end else begin
                        pos_idx <= pos_idx - 8'd1;
                    end
                end
            end
            
            FINISHED: begin
                result <= dp_next[0];
                done <= 1'b1;
            end
        endcase
    end
end

endmodule