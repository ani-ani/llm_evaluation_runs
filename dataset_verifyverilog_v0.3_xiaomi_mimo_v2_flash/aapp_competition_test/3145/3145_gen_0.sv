module multiple_counter (
    input clk,
    input rst_n,
    input start,
    input [15:0] X,
    input [15:0] A,
    input [15:0] B,
    input [9:0] allowed_mask,
    output reg [15:0] count,
    output reg done
);

localparam [2:0] IDLE         = 3'd0;
localparam [2:0] CHECK        = 3'd1;
localparam [2:0] CHECK_DIGITS = 3'd2;
localparam [2:0] EXTRACT      = 3'd3;
localparam [2:0] COUNT_UP     = 3'd4;
localparam [2:0] INCREMENT    = 3'd5;
localparam [2:0] DONE         = 3'd6;

reg [2:0] state;
reg [2:0] next_state;

reg [15:0] current_num;
reg [15:0] remainder;
reg [15:0] accumulated_count;
reg [15:0] temp_num;
reg [3:0] digit;
reg valid_flag;

wire [15:0] remainder_next;
wire [3:0] digit_next;

// Combinational calculations
assign remainder_next = (remainder + 16'd1 >= X) ? 16'd0 : (remainder + 16'd1);
assign digit_next = temp_num % 4'd10;

// Next state logic
always @(*) begin
    case (state)
        IDLE: begin
            if (start)
                next_state = CHECK;
            else
                next_state = IDLE;
        end
        
        CHECK: begin
            if (current_num > B)
                next_state = DONE;
            else if (remainder == 16'd0)
                next_state = CHECK_DIGITS;
            else
                next_state = INCREMENT;
        end
        
        CHECK_DIGITS: begin
            if (current_num == 16'd0) begin
                if (allowed_mask[0])
                    next_state = COUNT_UP;
                else
                    next_state = INCREMENT;
            end else begin
                next_state = EXTRACT;
            end
        end
        
        EXTRACT: begin
            if (allowed_mask[digit_next] == 1'b0)
                next_state = INCREMENT;
            else if (temp_num / 4'd10 == 16'd0)
                next_state = COUNT_UP;
            else
                next_state = EXTRACT;
        end
        
        COUNT_UP: begin
            next_state = INCREMENT;
        end
        
        INCREMENT: begin
            next_state = CHECK;
        end
        
        DONE: begin
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

// State register and outputs
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        current_num <= 16'd0;
        remainder <= 16'd0;
        accumulated_count <= 16'd0;
        temp_num <= 16'd0;
        digit <= 4'd0;
        valid_flag <= 1'b0;
        count <= 16'd0;
        done <= 1'b0;
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    current_num <= A;
                    remainder <= A % X;
                    accumulated_count <= 16'd0;
                end
            end
            
            CHECK: begin
                // Already handled in next_state logic
            end
            
            CHECK_DIGITS: begin
                temp_num <= current_num;
                valid_flag <= 1'b1;
            end
            
            EXTRACT: begin
                digit <= digit_next;
                temp_num <= temp_num / 4'd10;
                if (allowed_mask[digit_next] == 1'b0) begin
                    valid_flag <= 1'b0;
                end
            end
            
            COUNT_UP: begin
                if (valid_flag) begin
                    accumulated_count <= accumulated_count + 16'd1;
                end
            end
            
            INCREMENT: begin
                current_num <= current_num + 16'd1;
                remainder <= remainder_next;
                valid_flag <= 1'b1;
            end
            
            DONE: begin
                count <= accumulated_count;
                done <= 1'b1;
            end
        endcase
    end
end

endmodule