module photo_optimizer(
    input clk,
    input rst_n,
    input start,
    input [9:0] friend_w [0:3],
    input [9:0] friend_h [0:3],
    output reg [31:0] min_area,
    output reg done,
    output reg valid
);

    // States
    localparam IDLE = 0;
    localparam LOAD_DATA = 1;
    localparam COMPUTE_HEIGHT = 2;
    localparam CHECK_FRIENDS = 3;
    localparam CALCULATE_AREA = 4;
    localparam UPDATE_MIN = 5;
    localparam DONE = 6;

    reg [3:0] state;
    reg [9:0] height;
    reg [9:0] w_reg [0:3];
    reg [9:0] h_reg [0:3];
    reg [1:0] friend_idx;
    
    // Intermediate calculation registers
    reg [1:0] mandatory_lie_count;
    reg invalid_h;
    reg [9:0] current_width_sum;
    reg [9:0] current_height_max;
    
    // Registers for optional lie-down sorting
    reg [1:0] optional_lie_budget;
    reg [9:0] width_save [0:3]; // Width reduction if lying down (w_i - h_i if h_i < w_i)
    reg [1:0] sort_idx;
    reg [1:0] pass_idx;
    
    // Candidate area calculation
    reg [31:0] current_area;
    
    // Sort loop variables
    reg [1:0] max_idx;
    reg [9:0] max_val;
    reg [1:0] swap_cnt;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            valid <= 0;
            min_area <= 32'hFFFFFFFF; // Max value
            height <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    valid <= 0;
                    if (start) begin
                        state <= LOAD_DATA;
                    end
                end
                
                LOAD_DATA: begin
                    // Load input data into internal registers
                    w_reg[0] <= friend_w[0];
                    w_reg[1] <= friend_w[1];
                    w_reg[2] <= friend_w[2];
                    w_reg[3] <= friend_w[3];
                    h_reg[0] <= friend_h[0];
                    h_reg[1] <= friend_h[1];
                    h_reg[2] <= friend_h[2];
                    h_reg[3] <= friend_h[3];
                    height <= 0;
                    min_area <= 32'hFFFFFFFF;
                    state <= COMPUTE_HEIGHT;
                    friend_idx <= 0;
                end
                
                COMPUTE_HEIGHT: begin
                    if (height > 1023) begin
                        state <= DONE;
                    end else begin
                        mandatory_lie_count <= 0;
                        invalid_h <= 0;
                        current_width_sum <= 0;
                        current_height_max <= 0;
                        friend_idx <= 0;
                        state <= CHECK_FRIENDS;
                    end
                end
                
                CHECK_FRIENDS: begin
                    // Check constraints for current friend
                    if (friend_idx < 4) begin
                        // Check if must lie down
                        if (h_reg[friend_idx] > height) begin
                            // Must lie down: use h as width, w as height
                            mandatory_lie_count <= mandatory_lie_count + 1;
                            // Check validity: width (h) must be <= height
                            if (h_reg[friend_idx] > height) begin
                                invalid_h <= 1;
                            end
                            current_width_sum <= current_width_sum + h_reg[friend_idx];
                            // Update max height (actual height is w)
                            if (w_reg[friend_idx] > current_height_max) begin
                                current_height_max <= w_reg[friend_idx];
                            end
                            // Mark width_save as 0 (not optional)
                            width_save[friend_idx] <= 0;
                        end else begin
                            // Can choose orientation
                            current_width_sum <= current_width_sum + w_reg[friend_idx];
                            if (h_reg[friend_idx] > current_height_max) begin
                                current_height_max <= h_reg[friend_idx];
                            end
                            // Calculate potential width reduction if lying down (only if beneficial)
                            if (h_reg[friend_idx] < w_reg[friend_idx]) begin
                                width_save[friend_idx] <= w_reg[friend_idx] - h_reg[friend_idx];
                            end else begin
                                width_save[friend_idx] <= 0;
                            end
                        end
                        friend_idx <= friend_idx + 1;
                    end else begin
                        // Done checking all friends
                        if (invalid_h) begin
                            // Invalid height, skip to next
                            height <= height + 1;
                            state <= COMPUTE_HEIGHT;
                        end else begin
                            // Calculate budget
                            if (mandatory_lie_count > 2) begin
                                // Constraint violated
                                height <= height + 1;
                                state <= COMPUTE_HEIGHT;
                            end else begin
                                optional_lie_budget <= 2 - mandatory_lie_count;
                                pass_idx <= 0;
                                state <= CALCULATE_AREA;
                            end
                        end
                    end
                end
                
                CALCULATE_AREA: begin
                    // Simple sorting of width_save to pick best options
                    // We only have budget for up to 2 friends, so simple logic
                    // If budget > 0, apply lie-down to friends with highest positive width_save
                    
                    if (optional_lie_budget > 0) begin
                        // Find friend with max width_save that isn't already forced down
                        // This is a simplified 1-pass selection due to cycle constraints
                        // We do this by iteratively finding max and updating width
                        
                        if (pass_idx == 0) begin
                            // First pass check
                            if (width_save[0] > width_save[1] && width_save[0] > width_save[2] && width_save[0] > width_save[3]) begin
                                if (width_save[0] > 0) begin
                                    current_width_sum <= current_width_sum - width_save[0];
                                    width_save[0] <= 0;
                                    optional_lie_budget <= optional_lie_budget - 1;
                                end
                            end else if (width_save[1] > width_save[2] && width_save[1] > width_save[3] && width_save[1] > 0) begin
                                current_width_sum <= current_width_sum - width_save[1];
                                width_save[1] <= 0;
                                optional_lie_budget <= optional_lie_budget - 1;
                            end else if (width_save[2] > width_save[3] && width_save[2] > 0) begin
                                current_width_sum <= current_width_sum - width_save[2];
                                width_save[2] <= 0;
                                optional_lie_budget <= optional_lie_budget - 1;
                            end else if (width_save[3] > 0) begin
                                current_width_sum <= current_width_sum - width_save[3];
                                width_save[3] <= 0;
                                optional_lie_budget <= optional_lie_budget - 1;
                            end
                            pass_idx <= 1;
                        end else if (pass_idx == 1 && optional_lie_budget > 0) begin
                            // Second pass check (remaining ones)
                            if (width_save[0] > width_save[1] && width_save[0] > width_save[2] && width_save[0] > width_save[3]) begin
                                if (width_save[0] > 0) begin
                                    current_width_sum <= current_width_sum - width_save[0];
                                    width_save[0] <= 0;
                                    optional_lie_budget <= optional_lie_budget - 1;
                                end
                            end else if (width_save[1] > width_save[2] && width_save[1] > width_save[3] && width_save[1] > 0) begin
                                current_width_sum <= current_width_sum - width_save[1];
                                width_save[1] <= 0;
                                optional_lie_budget <= optional_lie_budget - 1;
                            end else if (width_save[2] > width_save[3] && width_save[2] > 0) begin
                                current_width_sum <= current_width_sum - width_save[2];
                                width_save[2] <= 0;
                                optional_lie_budget <= optional_lie_budget - 1;
                            end else if (width_save[3] > 0) begin
                                current_width_sum <= current_width_sum - width_save[3];
                                width_save[3] <= 0;
                                optional_lie_budget <= optional_lie_budget - 1;
                            end
                            pass_idx <= 2;
                        end else begin
                            state <= UPDATE_MIN;
                        end
                    end else begin
                        state <= UPDATE_MIN;
                    end
                end
                
                UPDATE_MIN: begin
                    // Calculate W * H
                    current_area <= current_width_sum * current_height_max;
                    // Compare and update min
                    if ((current_width_sum * current_height_max) < min_area && (current_width_sum * current_height_max) > 0) begin
                        min_area <= current_width_sum * current_height_max;
                    end
                    height <= height + 1;
                    state <= COMPUTE_HEIGHT;
                end
                
                DONE: begin
                    done <= 1;
                    valid <= 1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
