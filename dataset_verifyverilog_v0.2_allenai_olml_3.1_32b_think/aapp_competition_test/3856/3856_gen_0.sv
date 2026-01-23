module photo_optimizer (
    input clk,
    input rst_n,
    input start,
    input [9:0] friend_w [0:3],
    input [9:0] friend_h [0:3],
    output reg [31:0] min_area,
    output reg done,
    output reg valid
);

reg [9:0] internal_friend_w [0:3];
reg [9:0] internal_friend_h [0:3];
reg [9:0] current_height;
reg [2:0] mandatory_lie_count;
reg is_invalid;
reg [11:0] current_width;
reg [31:0] min_area_reg;
reg done_reg;
reg valid_reg;

reg [2:0] state;
localparam IDLE = 3'd0, LOAD_DATA = 3'd1, COMPUTE_HEIGHT = 3'd2, CHECK_FRIENDS = 3'd3, CALCULATE_AREA = 3'd4, UPDATE_MIN = 3'd5, DONE = 3'd6;
reg [2:0] next_state;

always @(posedge clk) begin
    if (!rst_n) begin
        internal_friend_w <= 0;
        internal_friend_h <= 0;
        current_height <= 0;
        mandatory_lie_count <= 0;
        is_invalid <= 0;
        current_width <= 0;
        min_area_reg <= 0;
        done_reg <= 0;
        valid_reg <= 0;
        state <= IDLE;
        next_state <= 0;
    end else begin
        state <= next_state;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_DATA;
                end else begin
                    next_state = IDLE;
                end
            end
            LOAD_DATA: begin
                internal_friend_w <= friend_w;
                internal_friend_h <= friend_h;
                next_state = COMPUTE_HEIGHT;
            end
            COMPUTE_HEIGHT: begin
                if (current_height < 1023) begin
                    next_state = CHECK_FRIENDS;
                end else begin
                    next_state = DONE;
                end
            end
            CHECK_FRIENDS: begin
                mandatory_lie_count <= 0;
                is_invalid <= 0;
                if (internal_friend_h[0] > current_height) begin
                    mandatory_lie_count <= mandatory_lie_count + 1;
                    if (internal_friend_w[0] > current_height) begin
                        is_invalid <= 1;
                    end
                end
                if (internal_friend_h[1] > current_height) begin
                    mandatory_lie_count <= mandatory_lie_count + 1;
                    if (internal_friend_w[1] > current_height) begin
                        is_invalid <= 1;
                    end
                end
                if (internal_friend_h[2] > current_height) begin
                    mandatory_lie_count <= mandatory_lie_count + 1;
                    if (internal_friend_w[2] > current_height) begin
                        is_invalid <= 1;
                    end
                end
                if (internal_friend_h[3] > current_height) begin
                    mandatory_lie_count <= mandatory_lie_count + 1;
                    if (internal_friend_w[3] > current_height) begin
                        is_invalid <= 1;
                    end
                end
                if (mandatory_lie_count > 2) begin
                    is_invalid <= 1;
                end
                if (is_invalid) begin
                    current_height <= current_height + 1;
                    next_state = COMPUTE_HEIGHT;
                end else begin
                    next_state = CALCULATE_AREA;
                end
            end
            CALCULATE_AREA: begin
                current_width <= 0;
                next_state = UPDATE_MIN;
            end
            UPDATE_MIN: begin
                if (min_area_reg > current_width * current_height) begin
                    min_area_reg <= current_width * current_height;
                end
                current_height <= current_height + 1;
                if (current_height == 1024) begin
                    next_state = DONE;
                end else begin
                    next_state = COMPUTE_HEIGHT;
                end
            end
            DONE: begin
                done_reg <= 1;
                valid_reg <= 1;
                next_state <= DONE;
            end
        endcase
    end
endmodule

assign min_area = min_area_reg;
assign done = done_reg;
assign valid = valid_reg;