module find_point_in_rects (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire signed [15:0] rect_x1 [0:15],
    input wire signed [15:0] rect_y1 [0:15],
    input wire signed [15:0] rect_x2 [0:15],
    input wire signed [15:0] rect_y2 [0:15],
    output reg signed [15:0] result_x,
    output reg signed [15:0] result_y,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] COMPUTE_PREFIX = 3'd1;
    localparam [2:0] COMPUTE_SUFFIX = 3'd2;
    localparam [2:0] CHECK_RESULT = 3'd3;
    localparam [2:0] OUTPUT_STATE = 3'd4;
    localparam [2:0] FINISH      = 3'd5;

    // Internal registers for prefix/suffix storage (32-bit for intermediate)
    reg signed [31:0] prefix_x1 [0:15];
    reg signed [31:0] prefix_y1 [0:15];
    reg signed [31:0] prefix_x2 [0:15];
    reg signed [31:0] prefix_y2 [0:15];
    
    reg signed [31:0] suffix_x1 [0:15];
    reg signed [31:0] suffix_y1 [0:15];
    reg signed [31:0] suffix_x2 [0:15];
    reg signed [31:0] suffix_y2 [0:15];

    reg [2:0] state, next_state;
    reg [3:0] i, j;
    reg signed [31:0] temp_x1, temp_y1, temp_x2, temp_y2;
    reg signed [31:0] intersect_x1, intersect_y1, intersect_x2, intersect_y2;
    reg found;
    reg [5:0] cycle_count;

    // Helper to scale coordinates (multiply by 1000)
    function automatic signed [15:0] scale_coord;
        input signed [15:0] val;
        reg signed [31:0] temp;
        begin
            temp = val * 16'sd1000;
            // Clamp to 16-bit signed range
            if (temp > 32'sd32767000) temp = 32'sd32767000;
            else if (temp < -32'sd32767000) temp = -32'sd32767000;
            scale_coord = temp[15:0];
        end
    endfunction

    // Registers for scaled input storage
    reg signed [15:0] scaled_x1 [0:15];
    reg signed [15:0] scaled_y1 [0:15];
    reg signed [15:0] scaled_x2 [0:15];
    reg signed [15:0] scaled_y2 [0:15];

    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_x <= 16'sd0;
            result_y <= 16'sd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            cycle_count <= 6'd0;
            found <= 1'b0;
            for (k = 0; k < 16; k = k + 1) begin
                prefix_x1[k] <= 32'sd0;
                prefix_y1[k] <= 32'sd0;
                prefix_x2[k] <= 32'sd0;
                prefix_y2[k] <= 32'sd0;
                suffix_x1[k] <= 32'sd0;
                suffix_y1[k] <= 32'sd0;
                suffix_x2[k] <= 32'sd0;
                suffix_y2[k] <= 32'sd0;
                scaled_x1[k] <= 16'sd0;
                scaled_y1[k] <= 16'sd0;
                scaled_x2[k] <= 16'sd0;
                scaled_y2[k] <= 16'sd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 6'd0;
                    found <= 1'b0;
                    if (start) begin
                        // Scale all coordinates first
                        for (k = 0; k < 16; k = k + 1) begin
                            scaled_x1[k] <= rect_x1[k] * 16'sd1000;
                            scaled_y1[k] <= rect_y1[k] * 16'sd1000;
                            scaled_x2[k] <= rect_x2[k] * 16'sd1000;
                            scaled_y2[k] <= rect_y2[k] * 16'sd1000;
                        end
                        state <= COMPUTE_PREFIX;
                        i <= 4'd0;
                    end
                end

                COMPUTE_PREFIX: begin
                    cycle_count <= cycle_count + 6'd1;
                    if (i == 4'd0) begin
                        // First prefix is just the first rectangle
                        prefix_x1[0] <= {16'sd0, scaled_x1[0]};
                        prefix_y1[0] <= {16'sd0, scaled_y1[0]};
                        prefix_x2[0] <= {16'sd0, scaled_x2[0]};
                        prefix_y2[0] <= {16'sd0, scaled_y2[0]};
                    end else begin
                        // Intersection with previous prefix
                        temp_x1 <= (prefix_x1[i-1] > {16'sd0, scaled_x1[i]}) ? prefix_x1[i-1] : {16'sd0, scaled_x1[i]};
                        temp_y1 <= (prefix_y1[i-1] > {16'sd0, scaled_y1[i]}) ? prefix_y1[i-1] : {16'sd0, scaled_y1[i]};
                        temp_x2 <= (prefix_x2[i-1] < {16'sd0, scaled_x2[i]}) ? prefix_x2[i-1] : {16'sd0, scaled_x2[i]};
                        temp_y2 <= (prefix_y2[i-1] < {16'sd0, scaled_y2[i]}) ? prefix_y2[i-1] : {16'sd0, scaled_y2[i]};
                        // Next cycle will store result
                        state <= state; // Hold
                    end
                    if (i < n-1) begin
                        i <= i + 4'd1;
                        state <= COMPUTE_PREFIX;
                    end else begin
                        // Done with prefixes, store final if valid
                        if (i > 4'd0) begin
                            prefix_x1[i] <= temp_x1;
                            prefix_y1[i] <= temp_y1;
                            prefix_x2[i] <= temp_x2;
                            prefix_y2[i] <= temp_y2;
                        end
                        state <= COMPUTE_SUFFIX;
                        i <= n-1;
                    end
                    // Handle storage for i=0 case
                    if (i == 4'd0) state <= COMPUTE_PREFIX;
                end

                COMPUTE_SUFFIX: begin
                    cycle_count <= cycle_count + 6'd1;
                    if (i == n-1) begin
                        // Last suffix is just the last rectangle
                        suffix_x1[n-1] <= {16'sd0, scaled_x1[n-1]};
                        suffix_y1[n-1] <= {16'sd0, scaled_y1[n-1]};
                        suffix_x2[n-1] <= {16'sd0, scaled_x2[n-1]};
                        suffix_y2[n-1] <= {16'sd0, scaled_y2[n-1]};
                    end else begin
                        // Intersection with next suffix
                        temp_x1 <= (suffix_x1[i+1] > {16'sd0, scaled_x1[i]}) ? suffix_x1[i+1] : {16'sd0, scaled_x1[i]};
                        temp_y1 <= (suffix_y1[i+1] > {16'sd0, scaled_y1[i]}) ? suffix_y1[i+1] : {16'sd0, scaled_y1[i]};
                        temp_x2 <= (suffix_x2[i+1] < {16'sd0, scaled_x2[i]}) ? suffix_x2[i+1] : {16'sd0, scaled_x2[i]};
                        temp_y2 <= (suffix_y2[i+1] < {16'sd0, scaled_y2[i]}) ? suffix_y2[i+1] : {16'sd0, scaled_y2[i]};
                        state <= state;
                    end
                    if (i > 4'd0) begin
                        i <= i - 4'd1;
                        state <= COMPUTE_SUFFIX;
                    end else begin
                        // Store final suffix value
                        if (n > 4'd1) begin
                            suffix_x1[0] <= temp_x1;
                            suffix_y1[0] <= temp_y1;
                            suffix_x2[0] <= temp_x2;
                            suffix_y2[0] <= temp_y2;
                        end
                        state <= CHECK_RESULT;
                        i <= 4'd0;
                    end
                    // Handle storage for i=n-1 case
                    if (i == n-1) state <= COMPUTE_SUFFIX;
                end

                CHECK_RESULT: begin
                    cycle_count <= cycle_count + 6'd1;
                    // For each i, check prefix[i] intersection with suffix[i]
                    // Special case: n=1, check prefix[0]
                    if (n == 4'd1) begin
                        intersect_x1 <= prefix_x1[0];
                        intersect_y1 <= prefix_y1[0];
                        intersect_x2 <= prefix_x2[0];
                        intersect_y2 <= prefix_y2[0];
                    end else begin
                        // Intersection of prefix[i] and suffix[i]
                        intersect_x1 <= (prefix_x1[i] > suffix_x1[i]) ? prefix_x1[i] : suffix_x1[i];
                        intersect_y1 <= (prefix_y1[i] > suffix_y1[i]) ? prefix_y1[i] : suffix_y1[i];
                        intersect_x2 <= (prefix_x2[i] < suffix_x2[i]) ? prefix_x2[i] : suffix_x2[i];
                        intersect_y2 <= (prefix_y2[i] < suffix_y2[i]) ? prefix_y2[i] : suffix_y2[i];
                    end
                    state <= OUTPUT_STATE;
                end

                OUTPUT_STATE: begin
                    cycle_count <= cycle_count + 6'd1;
                    // Check validity
                    if (intersect_x1 <= intersect_x2 && intersect_y1 <= intersect_y2) begin
                        result_x <= intersect_x1[15:0];
                        result_y <= intersect_y1[15:0];
                        found <= 1'b1;
                        state <= FINISH;
                    end else begin
                        // Try next i
                        if (i < n-1) begin
                            i <= i + 4'd1;
                            state <= CHECK_RESULT;
                        end else begin
                            // No valid point found (should not happen for n-1 requirement)
                            result_x <= 16'sd0;
                            result_y <= 16'sd0;
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule