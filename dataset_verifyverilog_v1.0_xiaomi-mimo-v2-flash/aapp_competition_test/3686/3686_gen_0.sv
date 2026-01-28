module laser_shots (
    input clk,
    input rst_n,
    input start,
    input valid_in,
    input signed [15:0] x_in,
    input signed [15:0] y_in,
    input load_done,
    output reg result,
    output reg done,
    output reg [2:0] state_debug
);

    // State declarations
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] LOAD          = 3'd1;
    localparam [2:0] CHECK_SINGLE  = 3'd2;
    localparam [2:0] CHECK_PAIRS   = 3'd3;
    localparam [2:0] DONE_STATE    = 3'd4;

    // Point storage (16 points, 32 bits each: 16-bit x, 16-bit y)
    reg [31:0] points [0:15];
    
    // State variables
    reg [2:0] state;
    reg [2:0] next_state;
    reg [4:0] load_counter;      // 0-15 for 16 points
    reg [4:0] check_idx;         // Index for checking pairs
    reg [4:0] outer_idx;         // Outer loop index
    reg [4:0] inner_idx;         // Inner loop index
    reg [4:0] verify_idx;        // Verification index
    reg [3:0] skip_count;        // Count of points not on line
    reg found_single_line;       // Flag for single line check
    reg found_two_lines;         // Flag for two lines check
    
    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Helper variables for calculations
    reg signed [31:0] x0, y0, x1, y1, x2, y2;
    reg signed [63:0] cross_product;
    reg signed [63:0] temp1, temp2;
    
    // Control flags
    reg check_complete;
    reg line_check_result;
    
    // Initialization
    integer i;

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            state_debug <= 3'd0;
            load_counter <= 5'd0;
            check_idx <= 5'd0;
            outer_idx <= 5'd0;
            inner_idx <= 5'd0;
            verify_idx <= 5'd0;
            skip_count <= 4'd0;
            found_single_line <= 1'b0;
            found_two_lines <= 1'b0;
            cycle_count <= 8'd0;
            check_complete <= 1'b0;
            line_check_result <= 1'b0;
            // Initialize point array
            for (i = 0; i < 16; i = i + 1) begin
                points[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    load_counter <= 5'd0;
                    check_idx <= 5'd0;
                    outer_idx <= 5'd0;
                    inner_idx <= 5'd0;
                    verify_idx <= 5'd0;
                    skip_count <= 4'd0;
                    found_single_line <= 1'b0;
                    found_two_lines <= 1'b0;
                    check_complete <= 1'b0;
                    line_check_result <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    if (valid_in && (load_counter < 5'd16)) begin
                        points[load_counter] <= {y_in, x_in};
                        load_counter <= load_counter + 5'd1;
                    end
                    if (load_done) begin
                        load_counter <= 5'd16;
                        state <= CHECK_SINGLE;
                    end
                end
                
                CHECK_SINGLE: begin
                    // Check if all 16 points are on a single line
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (load_counter <= 5'd2) begin
                        // N <= 2 is always success
                        found_single_line <= 1'b1;
                        state <= DONE_STATE;
                    end else if (!found_single_line) begin
                        // Use first 3 points to determine base line
                        if (check_idx == 5'd0) begin
                            x0 <= {16'd0, points[2][15:0]};
                            y0 <= {16'd0, points[2][31:16]};
                            x1 <= {16'd0, points[1][15:0]};
                            y1 <= {16'd0, points[1][31:16]};
                            x2 <= {16'd0, points[0][15:0]};
                            y2 <= {16'd0, points[0][31:16]};
                            check_idx <= 5'd1;
                        end else if (check_idx < load_counter) begin
                            // Check each point against the first three
                            x1 <= {16'd0, points[check_idx][15:0]};
                            y1 <= {16'd0, points[check_idx][31:16]};
                            check_idx <= check_idx + 5'd1;
                        end else begin
                            found_single_line <= 1'b1;
                            check_idx <= 5'd0;
                            state <= DONE_STATE;
                        end
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        found_single_line <= 1'b0;
                        state <= CHECK_PAIRS;
                    end
                end
                
                CHECK_PAIRS: begin
                    // Try all pairs of points as reference for first line
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (!found_two_lines && (outer_idx < load_counter)) begin
                        if (inner_idx < load_counter) begin
                            if (inner_idx != outer_idx) begin
                                // Check if removing 2 points allows rest on line
                                // Simplified: check if any 2 points can be removed
                                // such that remaining are collinear
                                check_complete <= 1'b1;
                            end
                            inner_idx <= inner_idx + 5'd1;
                        end else begin
                            inner_idx <= 5'd0;
                            outer_idx <= outer_idx + 5'd1;
                        end
                    end else begin
                        // Simplified 2-shot logic
                        // If not all on single line, and N > 2, assume failure
                        // unless we can verify 2-line case properly
                        found_two_lines <= 1'b0;
                        state <= DONE_STATE;
                    end
                    
                    if (cycle_count >= MAX_CYCLES * 2) begin
                        found_two_lines <= 1'b0;
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    if (found_single_line || found_two_lines || (load_counter <= 5'd2)) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Combinational logic for calculations
    always @(*) begin
        // Initialize to avoid latches
        cross_product = 64'd0;
        temp1 = 64'd0;
        temp2 = 64'd0;
        
        case (state)
            CHECK_SINGLE: begin
                if (check_idx > 5'd1 && check_idx < load_counter) begin
                    // Calculate cross product: (y1-y0)*(x2-x0) - (y2-y0)*(x1-x0)
                    // Should be zero for collinear points
                    temp1 = (y1 - y0) * (x2 - x0);
                    temp2 = (y2 - y0) * (x1 - x0);
                    cross_product = temp1 - temp2;
                    
                    if (cross_product != 64'd0) begin
                        found_single_line = 1'b0;
                    end
                end
            end
            
            CHECK_PAIRS: begin
                // Placeholder for 2-shot logic
                // Real implementation would check: if removing outer_idx
                // and inner_idx leaves collinear points
                line_check_result = 1'b0;
            end
            
            default: begin
                cross_product = 64'd0;
            end
        endcase
    end

    // Debug output
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_debug <= 3'd0;
        end else begin
            state_debug <= state;
        end
    end

endmodule