module DigitDivisibleFinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] startnum,
    input wire [15:0] endnum,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_NUM = 3'd1;
    localparam [2:0] EXTRACT_DIGIT = 3'd2;
    localparam [2:0] CHECK_DIVISIBILITY = 3'd3;
    localparam [2:0] NEXT_NUM = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] current_num;
    reg [15:0] temp_num;
    reg [3:0] digit;
    reg [3:0] digit_count;
    reg [3:0] digit_index;
    reg [3:0] cycle_count;
    reg [3:0] digit_array [0:4];
    reg [3:0] digit_ptr;
    reg digit_valid;
    reg all_divisible;
    reg [7:0] max_cycles;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            current_num <= 16'd0;
            temp_num <= 16'd0;
            digit <= 4'd0;
            digit_count <= 4'd0;
            digit_index <= 4'd0;
            cycle_count <= 8'd0;
            digit_ptr <= 4'd0;
            digit_valid <= 1'b0;
            all_divisible <= 1'b1;
            max_cycles <= 8'd1024;
            
            // Initialize digit array
            digit_array[0] <= 4'd0;
            digit_array[1] <= 4'd0;
            digit_array[2] <= 4'd0;
            digit_array[3] <= 4'd0;
            digit_array[4] <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_NUM;
                end else begin
                    next_state = IDLE;
                end
            end
            
            CHECK_NUM: begin
                if (current_num > endnum) begin
                    next_state = FINISH;
                end else begin
                    next_state = EXTRACT_DIGIT;
                end
            end
            
            EXTRACT_DIGIT: begin
                if (digit_index == digit_count) begin
                    next_state = CHECK_DIVISIBILITY;
                end else begin
                    next_state = EXTRACT_DIGIT;
                end
            end
            
            CHECK_DIVISIBILITY: begin
                if (digit_ptr == digit_count) begin
                    if (all_divisible && digit_valid) begin
                        next_state = FINISH;
                    end else begin
                        next_state = NEXT_NUM;
                    end
                end else begin
                    next_state = CHECK_DIVISIBILITY;
                end
            end
            
            NEXT_NUM: begin
                next_state = CHECK_NUM;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized in state transition
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        current_num <= startnum;
                        temp_num <= startnum;
                        digit_count <= 4'd0;
                        digit_index <= 4'd0;
                        digit_ptr <= 4'd0;
                        digit_valid <= 1'b1;
                        all_divisible <= 1'b1;
                        cycle_count <= 8'd0;
                        
                        // Initialize digit array
                        digit_array[0] <= 4'd0;
                        digit_array[1] <= 4'd0;
                        digit_array[2] <= 4'd0;
                        digit_array[3] <= 4'd0;
                        digit_array[4] <= 4'd0;
                    end
                end
                
                CHECK_NUM: begin
                    // Count digits in current_num
                    temp_num <= current_num;
                    digit_count <= 4'd0;
                    digit_index <= 4'd0;
                    digit_valid <= 1'b1;
                    all_divisible <= 1'b1;
                    
                    // Initialize digit array
                    digit_array[0] <= 4'd0;
                    digit_array[1] <= 4'd0;
                    digit_array[2] <= 4'd0;
                    digit_array[3] <= 4'd0;
                    digit_array[4] <= 4'd0;
                    
                    // Count digits
                    if (temp_num >= 16'd10000) begin
                        digit_count <= 4'd5;
                    end else if (temp_num >= 16'd1000) begin
                        digit_count <= 4'd4;
                    end else if (temp_num >= 16'd100) begin
                        digit_count <= 4'd3;
                    end else if (temp_num >= 16'd10) begin
                        digit_count <= 4'd2;
                    end else if (temp_num >= 16'd1) begin
                        digit_count <= 4'd1;
                    end else begin
                        digit_count <= 4'd0;
                    end
                end
                
                EXTRACT_DIGIT: begin
                    if (digit_index < digit_count) begin
                        digit <= temp_num % 16'd10;
                        temp_num <= temp_num / 16'd10;
                        digit_array[digit_index] <= digit;
                        digit_index <= digit_index + 4'd1;
                        
                        // Check for zero digit
                        if (digit == 4'd0) begin
                            digit_valid <= 1'b0;
                        end
                    end
                end
                
                CHECK_DIVISIBILITY: begin
                    if (digit_ptr < digit_count && digit_valid) begin
                        digit <= digit_array[digit_ptr];
                        if (digit != 4'd0 && current_num % digit != 0) begin
                            all_divisible <= 1'b0;
                        end
                        digit_ptr <= digit_ptr + 4'd1;
                    end
                end
                
                NEXT_NUM: begin
                    current_num <= current_num + 16'd1;
                    digit_ptr <= 4'd0;
                    cycle_count <= cycle_count + 8'd1;
                end
                
                FINISH: begin
                    if (all_divisible && digit_valid) begin
                        result <= current_num;
                        done <= 1'b1;
                    end else begin
                        result <= 16'd0;
                        done <= 1'b1;
                    end
                end
                
                default: begin
                    // Do nothing
                end
            endcase
        end
    end

    // Cycle counter safety check
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else begin
            if (state != IDLE && state != FINISH) begin
                if (cycle_count >= max_cycles) begin
                    next_state <= FINISH;
                    result <= 16'd0;
                    done <= 1'b1;
                end
            end
        end
    end

endmodule