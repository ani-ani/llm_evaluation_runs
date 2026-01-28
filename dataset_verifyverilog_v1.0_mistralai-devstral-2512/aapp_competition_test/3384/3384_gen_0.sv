module handsome_number_finder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] n_in,
    output reg [63:0] result0,
    output reg [63:0] result1,
    output reg [1:0] count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_HANDSOME = 3'd1;
    localparam [2:0] SEARCH_UP = 3'd2;
    localparam [2:0] SEARCH_DOWN = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Digit array storage (16 digits, 4 bits each)
    reg [3:0] digits [0:15];
    reg [5:0] num_digits;

    // Search variables
    reg [63:0] current_num;
    reg [63:0] best_up, best_down;
    reg [31:0] dist_up, dist_down;
    reg [9:0] search_counter;
    localparam [9:0] MAX_SEARCH = 10'd1000;

    // Handsome check variables
    reg is_handsome;
    reg [3:0] digit_count;
    reg [0:0] expected_parity;

    // Result tracking
    reg found_up, found_down;

    // Decimal conversion variables
    reg [63:0] temp_num;
    reg [5:0] digit_pos;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            count <= 2'd0;
            result0 <= 64'd0;
            result1 <= 64'd0;
            
            // Initialize all registers
            current_num <= 64'd0;
            best_up <= 64'd0;
            best_down <= 64'd0;
            dist_up <= 32'd0;
            dist_down <= 32'd0;
            search_counter <= 10'd0;
            is_handsome <= 1'b0;
            digit_count <= 6'd0;
            expected_parity <= 1'b0;
            temp_num <= 64'd0;
            digit_pos <= 6'd0;
            found_up <= 1'b0;
            found_down <= 1'b0;
            
            // Initialize digit array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                digits[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_HANDSOME;
                end
            end
            
            CHECK_HANDSOME: begin
                if (is_handsome) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = SEARCH_UP;
                end
            end
            
            SEARCH_UP: begin
                if (found_up && found_down) begin
                    next_state = DONE_STATE;
                end else if (search_counter >= MAX_SEARCH) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = SEARCH_DOWN;
                end
            end
            
            SEARCH_DOWN: begin
                if (found_up && found_down) begin
                    next_state = DONE_STATE;
                end else if (search_counter >= MAX_SEARCH) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = SEARCH_UP;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Main computation logic
    always @(posedge clk) begin
        if (rst_n) begin
            case (state)
                IDLE: begin
                    // Store input number
                    current_num <= n_in;
                    temp_num <= n_in;
                    digit_pos <= 6'd0;
                    num_digits <= 6'd0;
                    
                    // Initialize digit array
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        digits[i] <= 4'd0;
                    end
                end
                
                CHECK_HANDSOME: begin
                    // Convert number to digits
                    if (digit_pos < 16 && temp_num > 64'd0) begin
                        digits[digit_pos] <= temp_num % 10;
                        temp_num <= temp_num / 10;
                        digit_pos <= digit_pos + 6'd1;
                    end else if (digit_pos < 16 && temp_num == 64'd0) begin
                        // Handle case where temp_num is 0
                        if (digit_pos == 6'd0) begin
                            digits[0] <= 4'd0;
                            digit_pos <= digit_pos + 6'd1;
                        end
                        num_digits <= digit_pos;
                        
                        // Check if handsome
                        if (num_digits > 6'd0) begin
                            is_handsome <= 1'b1;
                            expected_parity <= digits[num_digits-1] % 2;
                            digit_count <= 6'd0;
                        end else begin
                            is_handsome <= 1'b1; // Single digit is considered handsome
                        end
                    end else if (digit_count < num_digits) begin
                        // Check digit parity alternation
                        if (digits[num_digits-1-digit_count] % 2 != expected_parity) begin
                            is_handsome <= 1'b0;
                        end
                        expected_parity <= ~expected_parity;
                        digit_count <= digit_count + 6'd1;
                    end
                end
                
                SEARCH_UP: begin
                    if (!found_up) begin
                        current_num <= n_in + 64'd1 + (search_counter * 64'd2);
                        // Check if current_num is handsome
                        temp_num <= current_num;
                        digit_pos <= 6'd0;
                        
                        // Convert to digits
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            digits[i] <= 4'd0;
                        end
                        
                        // Simple check for handsome (alternating parity)
                        reg [3:0] d0, d1, d2;
                        reg [0:0] p0, p1, p2;
                        
                        d0 <= current_num % 10;
                        d1 <= (current_num / 10) % 10;
                        d2 <= (current_num / 100) % 10;
                        
                        p0 <= d0 % 2;
                        p1 <= d1 % 2;
                        p2 <= d2 % 2;
                        
                        if ((p0 != p1) && (p1 != p2)) begin
                            found_up <= 1'b1;
                            best_up <= current_num;
                            dist_up <= current_num - n_in;
                        end
                    end
                    search_counter <= search_counter + 10'd1;
                end
                
                SEARCH_DOWN: begin
                    if (!found_down && n_in > 64'd1) begin
                        current_num <= n_in - 64'd1 - (search_counter * 64'd2);
                        // Check if current_num is handsome
                        temp_num <= current_num;
                        digit_pos <= 6'd0;
                        
                        // Convert to digits
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            digits[i] <= 4'd0;
                        end
                        
                        // Simple check for handsome (alternating parity)
                        reg [3:0] d0, d1, d2;
                        reg [0:0] p0, p1, p2;
                        
                        d0 <= current_num % 10;
                        d1 <= (current_num / 10) % 10;
                        d2 <= (current_num / 100) % 10;
                        
                        p0 <= d0 % 2;
                        p1 <= d1 % 2;
                        p2 <= d2 % 2;
                        
                        if ((p0 != p1) && (p1 != p2)) begin
                            found_down <= 1'b1;
                            best_down <= current_num;
                            dist_down <= n_in - current_num;
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    
                    // Pack results
                    if (is_handsome) begin
                        result0 <= n_in;
                        result1 <= 64'd0;
                        count <= 2'd1;
                    end else begin
                        if (found_up && found_down) begin
                            if (dist_up < dist_down) begin
                                result0 <= best_up;
                                result1 <= best_down;
                            end else begin
                                result0 <= best_down;
                                result1 <= best_up;
                            end
                            count <= 2'd2;
                        end else if (found_up) begin
                            result0 <= best_up;
                            result1 <= 64'd0;
                            count <= 2'd1;
                        end else if (found_down) begin
                            result0 <= best_down;
                            result1 <= 64'd0;
                            count <= 2'd1;
                        end else begin
                            result0 <= 64'd0;
                            result1 <= 64'd0;
                            count <= 2'd0;
                        end
                    end
                end
                
                default: begin
                    // Reset all signals
                    done <= 1'b0;
                    count <= 2'd0;
                    result0 <= 64'd0;
                    result1 <= 64'd0;
                    is_handsome <= 1'b0;
                    found_up <= 1'b0;
                    found_down <= 1'b0;
                    search_counter <= 10'd0;
                end
            endcase
        end
    end

endmodule