module longest_repeated_substring (
    input clk,
    input rst_n,
    input start,
    input [7:0] char0, char1, char2, char3, char4, char5, char6, char7,
    input [7:0] char8, char9, char10, char11, char12, char13, char14, char15,
    input [3:0] length_in,
    output reg [4:0] result,
    output reg done
);

// State definitions
localparam [1:0] IDLE = 2'd0;
localparam [1:0] INIT = 2'd1;
localparam [1:0] CHECK = 2'd2;
localparam [1:0] NEXT_LEN = 2'd3;
localparam [1:0] FINISHED = 2'd4;

reg [1:0] state, next_state;
reg [4:0] current_len, next_current_len;
reg [3:0] start_i, next_start_i;
reg [3:0] start_j, next_start_j;
reg [4:0] best_result, next_best_result;

// Char array for easy access
wire [7:0] chars [0:15];
assign chars[0] = char0;  assign chars[1] = char1;  assign chars[2] = char2;  assign chars[3] = char3;
assign chars[4] = char4;  assign chars[5] = char5;  assign chars[6] = char6;  assign chars[7] = char7;
assign chars[8] = char8;  assign chars[9] = char9;  assign chars[10] = char10; assign chars[11] = char11;
assign chars[12] = char12; assign chars[13] = char13; assign chars[14] = char14; assign chars[15] = char15;

// Combinational substring comparison
reg substr_match;
always @(*) begin
    substr_match = 1'b1;
    if (current_len == 0 || start_i + current_len > length_in || start_j + current_len > length_in) begin
        substr_match = 1'b0;
    end else begin
        integer k;
        for (k = 0; k < 15; k = k + 1) begin
            if (k < current_len) begin
                if (chars[start_i + k] != chars[start_j + k]) begin
                    substr_match = 1'b0;
                end
            end
        end
    end
end

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        current_len <= 5'd0;
        start_i <= 4'd0;
        start_j <= 4'd0;
        best_result <= 5'd0;
        done <= 1'b0;
        result <= 5'd0;
    end else begin
        state <= next_state;
        current_len <= next_current_len;
        start_i <= next_start_i;
        start_j <= next_start_j;
        best_result <= next_best_result;
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    next_current_len = current_len;
    next_start_i = start_i;
    next_start_j = start_j;
    next_best_result = best_result;
    done = 1'b0;
    result = best_result;
    
    case (state)
        IDLE: begin
            if (start) begin
                next_state = INIT;
            end
        end
        
        INIT: begin
            next_current_len = (length_in > 1) ? length_in - 1 : 0;
            next_start_i = 4'd0;
            next_start_j = 4'd1;
            next_best_result = 5'd0;
            next_state = CHECK;
        end
        
        CHECK: begin
            if (substr_match) begin
                next_best_result = current_len;
                next_state = NEXT_LEN;
            end else begin
                // Move to next pair
                if (start_j < length_in - current_len) begin
                    next_start_j = start_j + 1;
                end else begin
                    next_start_j = start_i + 2;
                    next_start_i = start_i + 1;
                    if (start_i + 1 >= length_in - current_len) begin
                        next_state = NEXT_LEN;
                    end
                end
            end
        end
        
        NEXT_LEN: begin
            if (current_len > 1) begin
                next_current_len = current_len - 1;
                next_start_i = 4'd0;
                next_start_j = 4'd1;
                next_state = CHECK;
            end else begin
                next_state = FINISHED;
            end
        end
        
        FINISHED: begin
            done = 1'b1;
            if (!start) begin
                next_state = IDLE;
            end
        end
        
        default: next_state = IDLE;
    endcase
end

endmodule