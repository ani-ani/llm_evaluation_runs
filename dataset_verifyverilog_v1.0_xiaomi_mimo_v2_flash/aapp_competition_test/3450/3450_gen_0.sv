module FindLastThreeDigits (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] n,
    output reg [9:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] INIT        = 3'd1;
    localparam [2:0] FACTORIAL   = 3'd2;
    localparam [2:0] ADJUST_POW2 = 3'd3;
    localparam [2:0] FINISH      = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [9:0] current_n;
    reg [9:0] product;
    reg [9:0] pow2_acc;
    reg [9:0] target_n;
    reg [3:0] pow2_mod;  // exponent of 2 modulo 10 (cyclic period)
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // Helper signals for factorial computation
    wire [9:0] next_product;
    wire [9:0] next_current_n;
    wire [9:0] next_pow2_mod;
    wire factors_of_2;

    // Check if number has factors of 2
    assign factors_of_2 = (current_n[0] == 1'b0) ? 1'b1 : 1'b0;

    // Next product calculation (multiply by odd part of current_n)
    assign next_product = (current_n == 10'd1) ? 10'd1 :
                          (current_n[0] == 1'b0) ? product : 
                          (product * current_n) % 10'd1000;

    // Next n (remove factors of 2)
    assign next_current_n = (current_n == 10'd1) ? 10'd1 :
                            (current_n[0] == 1'b0) ? (current_n >> 1) :
                            (current_n - 10'd1);

    // Count factors of 2
    assign next_pow2_mod = (current_n == 10'd1) ? 10'd0 :
                           (current_n[0] == 1'b0) ? (pow2_mod + 4'd1) :
                           pow2_mod;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE:       next_state = (start) ? INIT : IDLE;
            INIT:       next_state = FACTORIAL;
            FACTORIAL:  next_state = (current_n == 10'd1) ? ADJUST_POW2 : FACTORIAL;
            ADJUST_POW2: next_state = (pow2_mod == 4'd0) ? FINISH : ADJUST_POW2;
            FINISH:     next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 10'd0;
            done <= 1'b0;
            current_n <= 10'd0;
            product <= 10'd0;
            pow2_acc <= 10'd1;
            pow2_mod <= 4'd0;
            target_n <= 10'd0;
            cycle_count <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        target_n <= n;
                    end
                end

                INIT: begin
                    current_n <= target_n;
                    product <= 10'd1;
                    pow2_acc <= 10'd1;
                    pow2_mod <= 4'd0;
                end

                FACTORIAL: begin
                    product <= next_product;
                    current_n <= next_current_n;
                    pow2_mod <= next_pow2_mod;
                end

                ADJUST_POW2: begin
                    if (pow2_mod != 4'd0) begin
                        pow2_acc <= (pow2_acc * 10'd2) % 10'd1000;
                        pow2_mod <= pow2_mod - 4'd1;
                    end
                end

                FINISH: begin
                    result <= (product * pow2_acc) % 10'd1000;
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    result <= 10'd0;
                    done <= 1'b0;
                end
            endcase

            // Override to prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b1;
                result <= 10'd0;
            end

            state <= next_state;
        end
    end
endmodule