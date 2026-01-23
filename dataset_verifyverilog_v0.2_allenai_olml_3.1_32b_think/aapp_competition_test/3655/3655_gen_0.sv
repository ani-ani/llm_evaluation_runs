module find_candidates (
    input clk,
    input rst_n,
    input start,
    input [2:0] robot_w,  // max 8
    input [2:0] robot_h,  // max 8
    input [2:0] floor_w,  // max 16
    input [2:0] floor_h,  // max 16
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
    reg [255:0] floor_img [0:15]; // 16 rows, each 16 bits

    reg [5:0] write_addr;  // 64 addresses for robot
    reg [7:0] floor_write_addr;  // 256 addresses for floor

    // State definitions
    localparam IDLE = 3'b000;
    localparam LOAD_ROBOT = 3'b001;
    localparam LOAD_FLOOR = 3'b010;
    localparam COMPUTE = 3'b011;
    localparam OUTPUT_RESULTS = 3'b100;
    localparam DONE_STATE = 3'b101;

    reg [2:0] state;

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
    reg [3:0] comp_rx;
    reg [3:0] comp_ry;


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 0;
            done <= 0;
            write_addr <= 0;
            floor_write_addr <= 0;
            candidate_count <= 0;
            output_index <= 0;
            compare_enable <= 0;
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 0;
                    done <= 0;
                    if (start) begin
                        state <= LOAD_ROBOT;
                        write_addr <= 0;
                    end
                end

                LOAD_ROBOT: begin
                    if (write_addr < robot_w * robot_h) begin
                        robot_img[write_addr] <= robot_pixel_value;
                        write_addr <= write_addr + 1;
                    end else begin
                        state <= LOAD_FLOOR;
                        floor_write_addr <= 0;
                    end
                end

                LOAD_FLOOR: begin
                    if (floor_write_addr < floor_w * floor_h) begin
                        // Store floor pixels row by row
                        if (floor_write_addr[3:0] == 0) begin
                            floor_img[floor_write_addr[7:4]] <= {15'b0, floor_pixel_value};
                        end else begin
                            floor_img[floor_write_addr[7:4]] <= {floor_img[floor_write_addr[7:4]][14:0], floor_pixel_value};
                        end
                        floor_write_addr <= floor_write_addr + 1;
                    end else begin
                        state <= COMPUTE;
                        offset_x <= 0;
                        offset_y <= 0;
                        max_match <= 0;
                        candidate_count <= 0;
                    end
                end

                COMPUTE: begin
                    if (offset_y <= floor_h - robot_h) begin
                        if (offset_x <= floor_w - robot_w) begin
                            if (compare_enable == 0) begin
                                compare_enable <= 1;
                                match_count <= 0;
                                rx <= 0;
                                ry <= 0;
                            end else begin
                                // Pixel comparison happening
                                if (rx < robot_w) begin
                                    if (ry < robot_h) begin
                                        // Get robot pixel
                                        robot_pixel <= robot_img[ry * 8 + rx];
                                        // Get floor pixel
                                        floor_pixel <= floor_img[offset_y + ry][offset_x + rx];
                                         // Count matches
                                        if (robot_pixel == floor_pixel) begin
                                            match_count <= match_count + 1;
                                        end
                                         // Move to next robot pixel
                                        if (rx == robot_w - 1) begin
                                            rx <= 0;
                                            ry <= ry + 1;
                                        end else begin
                                            rx <= rx + 1;
                                        end
                                    end else begin
                                        // Finished this position
                                        compare_enable <= 0;
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
                                        offset_x <= offset_x + 1;
                                    end
                                end
                            end
                        end else begin
                            offset_x <= 0;
                            offset_y <= offset_y + 1;
                            compare_enable <= 0;
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
                    // Stay done
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule