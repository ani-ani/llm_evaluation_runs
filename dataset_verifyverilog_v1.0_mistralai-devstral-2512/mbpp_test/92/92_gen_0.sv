module is_undulating (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] num,
    output reg is_undulating,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] CONVERT = 2'd1;
    localparam [1:0] CHECK   = 2'd2;
    localparam [1:0] FINISH  = 2'd3;
    
    reg [1:0] state, next_state;
    
    // Decimal digits array
    reg [3:0] digits [0:9];
    integer i;
    
    // Conversion variables
    reg [31:0] temp_num;
    reg [3:0] digit_count;
    
    // Check variables
    reg [3:0] len;
    reg is_undulating_reg;
    reg done_reg;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            is_undulating <= 1'b0;
            done <= 1'b0;
            
            // Initialize digits array
            for (i = 0; i < 10; i = i + 1) begin
                digits[i] <= 4'd0;
            end
            digit_count <= 4'd0;
            temp_num <= 32'd0;
            len <= 4'd0;
            is_undulating_reg <= 1'b0;
            done_reg <= 1'b0;
        end else begin
            state <= next_state;
            
            // Output registers
            is_undulating <= is_undulating_reg;
            done <= done_reg;
            done_reg <= 1'b0;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CONVERT;
                    temp_num = num;
                    digit_count = 4'd0;
                    
                    // Initialize digits array
                    for (i = 0; i < 10; i = i + 1) begin
                        digits[i] = 4'd0;
                    end
                end
            end
            
            CONVERT: begin
                // Convert number to decimal digits
                if (temp_num > 0) begin
                    digits[digit_count] = temp_num % 10;
                    temp_num = temp_num / 10;
                    digit_count = digit_count + 1;
                end else begin
                    // Reverse digits and count length
                    len = digit_count;
                    for (i = 0; i < len/2; i = i + 1) begin
                        digits[i] = digits[len - 1 - i];
                    end
                    next_state = CHECK;
                end
            end
            
            CHECK: begin
                is_undulating_reg = 1'b0;
                
                // Check if length > 2
                if (len > 2) begin
                    // Check for undulating pattern
                    for (i = 2; i < len; i = i + 1) begin
                        if (digits[i] == digits[i-2]) begin
                            is_undulating_reg = 1'b1;
                        end
                    end
                end
                next_state = FINISH;
            end
            
            FINISH: begin
                done_reg = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
endmodule