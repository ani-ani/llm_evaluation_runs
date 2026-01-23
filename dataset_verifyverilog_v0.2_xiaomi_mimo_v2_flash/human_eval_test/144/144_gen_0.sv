module fraction_simplifier (
    input clk,
    input rst_n,
    input start,
    input [127:0] frac1_str,
    input [127:0] frac2_str,
    output reg result,
    output reg done
);

    // State encoding
    localparam IDLE = 4'd0;
    localparam PARSE_NUM1 = 4'd1;
    localparam PARSE_DEN1 = 4'd2;
    localparam PARSE_NUM2 = 4'd3;
    localparam PARSE_DEN2 = 4'd4;
    localparam MULTIPLY = 4'd5;
    localparam GCD_LOOP = 4'd6;
    localparam CHECK = 4'd7;
    localparam DONE = 4'd8;

    // Internal registers
    reg [3:0] state;
    reg [3:0] next_state;
    
    // Parsing registers
    reg [7:0] idx;          // Byte index for parsing (0-15)
    reg [31:0] temp_num;    // Accumulator for current number
    reg parsing_frac1;      // 1 if parsing frac1, 0 if frac2
    reg parsing_num;        // 1 if parsing numerator, 0 if denominator
    
    // Storage for parsed values
    reg [31:0] num1;
    reg [31:0] den1;
    reg [31:0] num2;
    reg [31:0] den2;
    
    // Multiplication results (64-bit to prevent overflow)
    reg [63:0] num_prod;
    reg [63:0] den_prod;
    
    // GCD registers
    reg [63:0] gcd_a;
    reg [63:0] gcd_b;
    reg [63:0] gcd_rem;
    reg gcd_valid;
    
    // Helper signals
    wire [7:0] current_byte;
    wire [7:0] digit_val;
    
    // Select current byte based on which string we are parsing
    assign current_byte = parsing_frac1 ? 
                          frac1_str[(idx * 8) +: 8] : 
                          frac2_str[(idx * 8) +: 8];
    
    // ASCII to integer conversion (subtract 0x30)
    assign digit_val = current_byte - 8'h30;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = PARSE_NUM1;
                else next_state = IDLE;
            end
            PARSE_NUM1: begin
                if (current_byte == 8'h2F && idx < 16) next_state = PARSE_DEN1;
                else if (idx >= 16) next_state = PARSE_DEN1; // Safety
                else next_state = PARSE_NUM1;
            end
            PARSE_DEN1: begin
                if ((current_byte == 8'h00 || current_byte == 8'h20 || idx >= 16) && idx > 0) next_state = PARSE_NUM2;
                else if (idx >= 16) next_state = PARSE_NUM2;
                else next_state = PARSE_DEN1;
            end
            PARSE_NUM2: begin
                if (current_byte == 8'h2F && idx < 16) next_state = PARSE_DEN2;
                else if (idx >= 16) next_state = PARSE_DEN2;
                else next_state = PARSE_NUM2;
            end
            PARSE_DEN2: begin
                if ((current_byte == 8'h00 || current_byte == 8'h20 || idx >= 16) && idx > 0) next_state = MULTIPLY;
                else if (idx >= 16) next_state = MULTIPLY;
                else next_state = PARSE_DEN2;
            end
            MULTIPLY: next_state = GCD_LOOP;
            GCD_LOOP: begin
                if (gcd_b == 64'd0) next_state = CHECK;
                else next_state = GCD_LOOP;
            end
            CHECK: next_state = DONE;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            result <= 1'b0;
            done <= 1'b0;
            idx <= 8'd0;
            temp_num <= 32'd0;
            num1 <= 32'd0;
            den1 <= 32'd0;
            num2 <= 32'd0;
            den2 <= 32'd0;
            num_prod <= 64'd0;
            den_prod <= 64'd0;
            gcd_a <= 64'd0;
            gcd_b <= 64'd0;
            gcd_rem <= 64'd0;
            parsing_frac1 <= 1'b1;
            parsing_num <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    idx <= 8'd0;
                    temp_num <= 32'd0;
                    parsing_frac1 <= 1'b1;
                    parsing_num <= 1'b1;
                end
                
                PARSE_NUM1: begin
                    if (current_byte == 8'h2F) begin
                        // Found slash, store numerator
                        num1 <= temp_num;
                        temp_num <= 32'd0;
                        parsing_num <= 1'b0; // Next will be denominator
                        idx <= idx + 1;
                    end else if (current_byte >= 8'h30 && current_byte <= 8'h39) begin
                        // Digit found, accumulate
                        temp_num <= temp_num * 10 + digit_val;
                        idx <= idx + 1;
                    end else begin
                        // Skip non-digits
                        idx <= idx + 1;
                    end
                end
                
                PARSE_DEN1: begin
                    if ((current_byte == 8'h00 || current_byte == 8'h20) && temp_num != 0) begin
                        // End of string, store denominator
                        den1 <= temp_num;
                        temp_num <= 32'd0;
                        parsing_frac1 <= 1'b0;
                        parsing_num <= 1'b1;
                        idx <= idx + 1;
                    end else if (current_byte >= 8'h30 && current_byte <= 8'h39) begin
                        // Digit found, accumulate
                        temp_num <= temp_num * 10 + digit_val;
                        idx <= idx + 1;
                    end else if (temp_num != 0 && idx >= 16) begin
                        // End of array, store what we have
                        den1 <= temp_num;
                        temp_num <= 32'd0;
                        parsing_frac1 <= 1'b0;
                        parsing_num <= 1'b1;
                        idx <= 8'd0;
                    end else begin
                        idx <= idx + 1;
                    end
                end
                
                PARSE_NUM2: begin
                    if (current_byte == 8'h2F) begin
                        // Found slash, store numerator
                        num2 <= temp_num;
                        temp_num <= 32'd0;
                        parsing_num <= 1'b0;
                        idx <= idx + 1;
                    end else if (current_byte >= 8'h30 && current_byte <= 8'h39) begin
                        // Digit found, accumulate
                        temp_num <= temp_num * 10 + digit_val;
                        idx <= idx + 1;
                    end else begin
                        idx <= idx + 1;
                    end
                end
                
                PARSE_DEN2: begin
                    if ((current_byte == 8'h00 || current_byte == 8'h20) && temp_num != 0) begin
                        // End of string, store denominator
                        den2 <= temp_num;
                        temp_num <= 32'd0;
                        idx <= 8'd0;
                    end else if (current_byte >= 8'h30 && current_byte <= 8'h39) begin
                        // Digit found, accumulate
                        temp_num <= temp_num * 10 + digit_val;
                        idx <= idx + 1;
                    end else if (temp_num != 0 && idx >= 16) begin
                        // End of array, store what we have
                        den2 <= temp_num;
                        temp_num <= 32'd0;
                        idx <= 8'd0;
                    end else begin
                        idx <= idx + 1;
                    end
                end
                
                MULTIPLY: begin
                    // Calculate products using 64-bit multiplication
                    num_prod <= num1 * num2;
                    den_prod <= den1 * den2;
                end
                
                GCD_LOOP: begin
                    if (gcd_b != 64'd0) begin
                        // Euclidean algorithm: a, b = b, a % b
                        gcd_a <= gcd_b;
                        gcd_b <= gcd_rem;
                    end else begin
                        // Initialize on first cycle or continue
                        // If just entering GCD state from MULTIPLY
                        // (Handled by transition logic, but need to seed values)
                    end
                end
                \                CHECK: begin
                    // Compare gcd with denominator product
                    if (gcd_a == den_prod) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    // GCD remainder calculation (combinational)
    always @(*) begin
        if (state == GCD_LOOP && gcd_b != 64'd0) begin
            gcd_rem = gcd_a % gcd_b;
        end else begin
            gcd_rem = 64'd0;
        end
    end
    
    // Initialize GCD registers when entering GCD_LOOP from MULTIPLY
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gcd_a <= 64'd0;
            gcd_b <= 64'd0;
        end else if (state == MULTIPLY && next_state == GCD_LOOP) begin
            // Seed GCD with product values
            gcd_a <= num_prod;
            gcd_b <= den_prod;
        end
    end

endmodule
