module fraction_simplifier (
    input clk,
    input rst_n,
    input start,
    input [127:0] frac1_str,
    input [127:0] frac2_str,
    output reg result,
    output reg done
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        PARSE_NUM1,
        PARSE_DEN1,
        PARSE_NUM2,
        PARSE_DEN2,
        MULTIPLY,
        GCD_LOOP,
        CHECK,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Parsed values
    reg [31:0] num1, den1, num2, den2;
    reg [63:0] num_prod, den_prod;
    reg [31:0] gcd_result;

    // Parsing variables
    reg [3:0] index1, index2;
    reg [31:0] temp_num;
    reg [7:0] current_byte1, current_byte2;

    // GCD variables
    reg [31:0] a, b, temp;

    // Initialize outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
            current_state <= IDLE;
            index1 <= 0;
            index2 <= 0;
            temp_num <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            num1 <= 0;
            den1 <= 0;
            num2 <= 0;
            den2 <= 0;
            num_prod <= 0;
            den_prod <= 0;
            gcd_result <= 0;
            a <= 0;
            b <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        next_state = PARSE_NUM1;
                        index1 <= 0;
                        index2 <= 0;
                        temp_num <= 0;
                    end else begin
                        next_state = IDLE;
                    end
                end

                PARSE_NUM1: begin
                    current_byte1 = frac1_str[(index1*8)+:8];
                    if (current_byte1 == 8'h2F) begin
                        num1 <= temp_num;
                        temp_num <= 0;
                        index1 <= index1 + 1;
                        next_state = PARSE_DEN1;
                    end else begin
                        temp_num <= (temp_num * 10) + (current_byte1 - 8'h30);
                        index1 <= index1 + 1;
                        next_state = PARSE_NUM1;
                    end
                end

                PARSE_DEN1: begin
                    current_byte1 = frac1_str[(index1*8)+:8];
                    if (current_byte1 == 8'h00 || index1 == 16) begin
                        den1 <= temp_num;
                        temp_num <= 0;
                        index1 <= 0;
                        next_state = PARSE_NUM2;
                    end else begin
                        temp_num <= (temp_num * 10) + (current_byte1 - 8'h30);
                        index1 <= index1 + 1;
                        next_state = PARSE_DEN1;
                    end
                end

                PARSE_NUM2: begin
                    current_byte2 = frac2_str[(index2*8)+:8];
                    if (current_byte2 == 8'h2F) begin
                        num2 <= temp_num;
                        temp_num <= 0;
                        index2 <= index2 + 1;
                        next_state = PARSE_DEN2;
                    end else begin
                        temp_num <= (temp_num * 10) + (current_byte2 - 8'h30);
                        index2 <= index2 + 1;
                        next_state = PARSE_NUM2;
                    end
                end

                PARSE_DEN2: begin
                    current_byte2 = frac2_str[(index2*8)+:8];
                    if (current_byte2 == 8'h00 || index2 == 16) begin
                        den2 <= temp_num;
                        temp_num <= 0;
                        next_state = MULTIPLY;
                    end else begin
                        temp_num <= (temp_num * 10) + (current_byte2 - 8'h30);
                        index2 <= index2 + 1;
                        next_state = PARSE_DEN2;
                    end
                end

                MULTIPLY: begin
                    num_prod <= num1 * num2;
                    den_prod <= den1 * den2;
                    next_state = GCD_LOOP;
                    a <= num_prod[31:0];
                    b <= den_prod[31:0];
                end

                GCD_LOOP: begin
                    if (b == 0) begin
                        gcd_result <= a;
                        next_state = CHECK;
                    end else begin
                        temp <= a % b;
                        a <= b;
                        b <= temp;
                        next_state = GCD_LOOP;
                    end
                end

                CHECK: begin
                    if (gcd_result == den_prod[31:0]) begin
                        result <= 1;
                    end else begin
                        result <= 0;
                    end
                    next_state = DONE;
                end

                DONE: begin
                    done <= 1;
                    next_state = IDLE;
                end

                default: begin
                    next_state = IDLE;
                end
            endcase
        end
    end

    // Reset done signal when not in DONE state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
        end else if (current_state != DONE) begin
            done <= 0;
        end
    end

endmodule