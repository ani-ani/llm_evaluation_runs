module next_palindrome(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] num_in,
    output reg [31:0] result,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK_LEN  = 3'd1;
    localparam [2:0] MIRROR     = 3'd2;
    localparam [2:0] INCREMENT  = 3'd3;
    localparam [2:0] PROPAGATE  = 3'd4;
    localparam [2:0] CONVERT    = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // BCD digit storage (8 digits, 4 bits each)
    reg [3:0] digits [0:7];
    reg [3:0] temp_digits [0:7];
    reg [4:0] num_digits;
    reg [3:0] middle_idx;
    reg [3:0] carry;
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] k;
    reg [3:0] temp;

    // Convert number to BCD
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            valid <= 1'b1;
            cycle_count <= 8'd0;
            
            // Initialize all registers
            for (i = 0; i < 8; i = i + 1) begin
                digits[i] <= 4'd0;
                temp_digits[i] <= 4'd0;
            end
            num_digits <= 5'd0;
            middle_idx <= 4'd0;
            carry <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            temp <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Check if input is valid (<= 99999999)
                        if (num_in > 32'd99999999) begin
                            valid <= 1'b0;
                            next_state <= IDLE;
                        end else begin
                            valid <= 1'b1;
                            next_state <= CHECK_LEN;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK_LEN: begin
                    // Convert input to BCD digits
                    temp = num_in;
                    for (i = 0; i < 8; i = i + 1) begin
                        digits[i] <= temp % 10;
                        temp <= temp / 10;
                    end
                    
                    // Count number of digits
                    num_digits = 5'd0;
                    for (i = 7; i >= 0; i = i - 1) begin
                        if (digits[i] != 4'd0) begin
                            num_digits = i + 5'd1;
                        end
                    end
                    
                    // Calculate middle index
                    if (num_digits % 2 == 1'b0) begin
                        middle_idx = (num_digits / 2) - 4'd1;
                    end else begin
                        middle_idx = (num_digits / 2);
                    end
                    
                    next_state <= MIRROR;
                end

                MIRROR: begin
                    // Mirror left half to right half
                    for (i = 0; i < num_digits; i = i + 1) begin
                        temp_digits[i] = digits[i];
                    end
                    
                    // Mirror based on length
                    if (num_digits % 2 == 1'b0) begin
                        // Even length: mirror all
                        for (i = 0; i < num_digits / 2; i = i + 1) begin
                            temp_digits[num_digits - 1 - i] = temp_digits[i];
                        end
                    end else begin
                        // Odd length: mirror around middle
                        for (i = 0; i < (num_digits - 1) / 2; i = i + 1) begin
                            temp_digits[num_digits - 1 - i] = temp_digits[i];
                        end
                    end
                    
                    // Check if mirrored number is greater than input
                    reg [31:0] mirrored_num = 32'd0;
                    reg [31:0] input_num = num_in;
                    
                    for (i = 0; i < num_digits; i = i + 1) begin
                        mirrored_num = mirrored_num * 10 + temp_digits[i];
                    end
                    
                    if (mirrored_num > input_num) begin
                        next_state <= CONVERT;
                    end else begin
                        next_state <= INCREMENT;
                    end
                end

                INCREMENT: begin
                    // Start from middle digit and increment
                    carry = 4'd1;
                    i = middle_idx;
                    
                    // Increment middle digit(s)
                    if (num_digits % 2 == 1'b0) begin
                        // Even length: increment both middle digits
                        temp_digits[i] = temp_digits[i] + carry;
                        temp_digits[i + 1] = temp_digits[i];
                        carry = (temp_digits[i] > 9) ? 4'd1 : 4'd0;
                        temp_digits[i] = temp_digits[i] % 10;
                        temp_digits[i + 1] = temp_digits[i];
                        i = i - 1;
                    end else begin
                        // Odd length: increment middle digit
                        temp_digits[i] = temp_digits[i] + carry;
                        carry = (temp_digits[i] > 9) ? 4'd1 : 4'd0;
                        temp_digits[i] = temp_digits[i] % 10;
                        i = i - 1;
                    end
                    
                    next_state <= PROPAGATE;
                end

                PROPAGATE: begin
                    // Propagate carry to the left
                    if (carry == 4'd1 && i >= 0) begin
                        temp_digits[i] = temp_digits[i] + 4'd1;
                        carry = (temp_digits[i] > 9) ? 4'd1 : 4'd0;
                        temp_digits[i] = temp_digits[i] % 10;
                        i = i - 1;
                    end else begin
                        // Mirror again after increment
                        if (num_digits % 2 == 1'b0) begin
                            for (i = 0; i < num_digits / 2; i = i + 1) begin
                                temp_digits[num_digits - 1 - i] = temp_digits[i];
                            end
                        end else begin
                            for (i = 0; i < (num_digits - 1) / 2; i = i + 1) begin
                                temp_digits[num_digits - 1 - i] = temp_digits[i];
                            end
                        end
                        next_state <= CONVERT;
                    end
                end

                CONVERT: begin
                    // Convert BCD back to binary
                    result = 32'd0;
                    for (i = num_digits - 1; i >= 0; i = i - 1) begin
                        result = result * 10 + temp_digits[i];
                    end
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // State register update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Cycle counter for timeout
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else if (state != IDLE && state != DONE_STATE) begin
            if (cycle_count < MAX_CYCLES) begin
                cycle_count <= cycle_count + 8'd1;
            end else begin
                // Timeout - return to idle
                next_state <= IDLE;
                done <= 1'b0;
            end
        end
    end

endmodule