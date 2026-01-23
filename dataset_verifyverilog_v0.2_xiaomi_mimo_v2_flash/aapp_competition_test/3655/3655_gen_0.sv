module find_candidates (
    input clk,
    input rst_n,
    input start,
    input [2:0] robot_w,  // max 8
    input [2:0] robot_h,  // max 8
    input [3:0] floor_w,  // max 16
    input [3:0] floor_h,  // max 16
    input [6:0] robot_pixel_addr,  // 8*8=64 addresses
    input robot_pixel_value,
    input [7:0] floor_pixel_addr,  // 16*16=256 addresses
    input floor_pixel_value,
    output reg [3:0] result_x,  // output x coordinate
    output reg [3:0] result_y,  // output y coordinate
    output reg result_valid,     // high when output is valid
    output reg done              // computation complete
);

    // Internal memory for robot and floor images
    reg [7:0] robot_img [0:63];  // 8x8 = 64 pixels
    reg [15:0] floor_img [0:15]; // 16 rows, each 16 bits
    
    // State definitions
    localparam IDLE = 3'b000;
    localparam LOAD_ROBOT = 3'b001;
    localparam LOAD_FLOOR = 3'b010;
    localparam COMPUTE = 3'b011;
    localparam OUTPUT_RESULTS = 3'b100;
    localparam DONE_STATE = 3'b101;
    
    reg [2:0] state;
    
    // Load counters
    reg [5:0] load_robot_cnt;  // 64 addresses for robot
    reg [7:0] load_floor_cnt;  // 256 addresses for floor
    
    // Compute state variables
    reg [3:0] offset_x;  // x position in floor to overlay robot
    reg [3:0] offset_y;  // y position in floor to overlay robot
    reg [3:0] rx;        // robot x coordinate
    reg [3:0] ry;        // robot y coordinate
    reg [7:0] match_count;  // count of matching pixels (max 64)
    reg [7:0] max_match;    // maximum match count found
    
    // Store candidate positions (max 64 candidates for 16x16 floor)
    reg [3:0] candidate_x [0:63];
    reg [3:0] candidate_y [0:63];
    reg [5:0] candidate_count;
    reg [5:0] output_index;
    
    // Pixel comparison logic
    reg robot_pixel;
    reg floor_pixel;
    reg compare_enable;
    reg compare_done;
    
    // Precompute robot index for readability
    wire [5:0] robot_idx;
    assign robot_idx = ry * 8 + rx;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 0;
            done <= 0;
            load_robot_cnt <= 0;
            load_floor_cnt <= 0;
            candidate_count <= 0;
            output_index <= 0;
            compare_enable <= 0;
            compare_done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 0;
                    done <= 0;
                    if (start) begin
                        state <= LOAD_ROBOT;
                        load_robot_cnt <= 0;
                    end
                end
                
                LOAD_ROBOT: begin
                    // Load robot pixels from sequential input interface
                    if (load_robot_cnt < robot_w * robot_h) begin
                        robot_img[load_robot_cnt] <= robot_pixel_value;
                        load_robot_cnt <= load_robot_cnt + 1;
                    end else if (load_robot_cnt < 64) begin
                        // Fill remaining with zeros for unused pixels
                        robot_img[load_robot_cnt] <= 0;
                        load_robot_cnt <= load_robot_cnt + 1;
                    end else begin
                        state <= LOAD_FLOOR;
                        load_floor_cnt <= 0;
                    end
                end
                
                LOAD_FLOOR: begin
                    // Load floor pixels from sequential input interface
                    // floor_pixel_addr maps linear address to row/col
                    if (load_floor_cnt < floor_w * floor_h) begin
                        // Determine row and col from linear address
                        // For sequential loading, we track row/col
                        // Using floor_pixel_addr to index, but sequential mode means we count
                        if (load_floor_cnt[3:0] == 0) begin
                            floor_img[load_floor_cnt[7:4]] <= {15'b0, floor_pixel_value};
                        end else begin
                            floor_img[load_floor_cnt[7:4]] <= {floor_img[load_floor_cnt[7:4]][14:0], floor_pixel_value};
                        end
                        load_floor_cnt <= load_floor_cnt + 1;
                    end else if (load_floor_cnt < 256) begin
                        // Fill remaining with zeros
                        if (load_floor_cnt[3:0] == 0) begin
                            floor_img[load_floor_cnt[7:4]] <= 16'b0;
                        end
                        load_floor_cnt <= load_floor_cnt + 1;
                    end else begin
                        state <= COMPUTE;
                        offset_x <= 0;
                        offset_y <= 0;
                        max_match <= 0;
                        candidate_count <= 0;
                        compare_enable <= 0;
                        compare_done <= 0;
                    end
                end
                
                COMPUTE: begin
                    if (offset_y <= floor_h - robot_h) begin
                        if (offset_x <= floor_w - robot_w) begin
                            // Start comparison for this position
                            if (!compare_enable && !compare_done) begin
                                compare_enable <= 1;
                                match_count <= 0;
                                rx <= 0;
                                ry <= 0;
                            end else if (compare_enable) begin
                                // Get pixels (combinational read from arrays)
                                robot_pixel <= robot_img[robot_idx];
                                floor_pixel <= floor_img[offset_y + ry][offset_x + rx];
                                
                                // Count matches with one cycle delay for pixel read
                                if (rx == 0 && ry == 0) begin
                                    // First pixel, no comparison yet
                                    match_count <= 0;
                                end else begin
                                    if (robot_pixel == floor_pixel) begin
                                        match_count <= match_count + 1;
                                    end
                                end
                                
                                // Advance to next pixel
                                if (rx == robot_w - 1) begin
                                    if (ry == robot_h - 1) begin
                                        // Last pixel of this position - finalize comparison
                                        // Need to check last pixel match
                                        if (robot_pixel == floor_pixel) begin
                                            match_count <= match_count + 1;
                                        end
                                        compare_enable <= 0;
                                        compare_done <= 1;
                                    end else begin
                                        rx <= 0;
                                        ry <= ry + 1;
                                    end
                                end else begin
                                    rx <= rx + 1;
                                end
                            end else if (compare_done) begin
                                // Update candidates based on finished comparison
                                // match_count now includes all pixels
                                if (match_count > max_match) begin
                                    max_match <= match_count;
                                    candidate_count <= 1;
                                    candidate_x[0] <= offset_x;
                                    candidate_y[0] <= offset_y;
                                end else if (match_count == max_match) begin
                                    if (candidate_count < 64) begin
                                        candidate_x[candidate_count] <= offset_x;
                                        candidate_y[candidate_count] <= offset_y;
                                        candidate_count <= candidate_count + 1;
                                    end
                                end
                                compare_done <= 0;
                                offset_x <= offset_x + 1;
                            end
                        end else begin
                            offset_x <= 0;
                            offset_y <= offset_y + 1;
                            compare_enable <= 0;
                            compare_done <= 0;
                        end
                    end else begin
                        state <= OUTPUT_RESULTS;
                        output_index <= 0;
                    end
                end
                
                OUTPUT_RESULTS: begin
                    if (output_index < candidate_count) begin
                        result_x <= candidate_x[output_index];
                        result_y <= candidate_y[output_index];
                        result_valid <= 1;
                        output_index <= output_index + 1;
                    end else begin
                        result_valid <= 0;
                        state <= DONE_STATE;
                        done <= 1;
                    end
                end
                
                DONE_STATE: begin
                    // Stay done until reset or start
                    done <= 1;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule