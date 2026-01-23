module lights_time (
    input wire [15:0] s,
    input wire [3:0] len,
    output reg [4:0] time
);

    // Internal signals
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] active_count;
    reg [15:0] s_masked;
    reg [15:0] s_shifted;
    reg [4:0] max_gap;
    reg [4:0] current_gap;
    reg [4:0] start_pos;
    reg [4:0] end_pos;
    reg found_start;
    reg found_end;
    
    always @(*) begin
        // Initialize
        s_masked = 16'd0;
        active_count = 4'd0;
        s_shifted = 16'd0;
        
        // Mask s based on len (keep only relevant bits)
        for (i = 0; i < 16; i = i + 1) begin
            if (i < len) begin
                s_masked[i] = s[i];
                if (s[i]) active_count = active_count + 4'd1;
            end else begin
                s_masked[i] = 1'b0;
            end
        end
        
        // Default case: no lights on
        if (active_count == 4'd0) begin
            time = 5'd2;
        end
        // All lights on
        else if (active_count == len) begin
            time = 5'd0;
        end
        // Single light on
        else if (active_count == 4'd1) begin
            time = 5'd0;
        end
        else begin
            // For multiple lights on, find the largest gap between on-lights
            max_gap = 5'd0;
            current_gap = 5'd0;
            start_pos = 5'd0;
            end_pos = 5'd0;
            found_start = 1'b0;
            found_end = 1'b0;
            
            // Find first on-light
            for (i = 0; i < len; i = i + 1) begin
                if (s_masked[i]) begin
                    start_pos = i;
                    found_start = 1'b1;
                    break;
                end
            end
            
            // Find last on-light
            if (found_start) begin
                for (i = len - 1; i != 5'd15; i = i - 1) begin
                    if (s_masked[i]) begin
                        end_pos = i;
                        found_end = 1'b1;
                        break;
                    end
                    if (i == 5'd0) break;
                end
            end
            
            // Calculate gaps between consecutive on-lights
            if (found_start && found_end) begin
                current_gap = 5'd0;
                for (i = start_pos + 4'd1; i <= end_pos; i = i + 4'd1) begin
                    if (s_masked[i]) begin
                        // Gap found between on-lights
                        if (current_gap > max_gap) begin
                            max_gap = current_gap;
                        end
                        current_gap = 5'd0;
                    end else begin
                        current_gap = current_gap + 5'd1;
                    end
                end
            end
            
            // Time is the maximum gap found
            if (max_gap > 5'd0) begin
                time = max_gap;
            end else begin
                time = 5'd0;
            end
        end
    end

endmodule