module rational_to_fraction (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] integer_part,   // integer part (0-999)
    input wire [43:0] digits_packed, // 11 digits, each 4 bits, MSB first
    input wire [3:0] L,              // number of valid fractional digits (1-11)
    input wire [3:0] R,              // repeat count (1-11, <= L)
    output reg [63:0] numerator,
    output reg [63:0] denominator,
    output reg done
);

// State declarations
localparam [2:0] IDLE        = 3'd0;
localparam [2:0] COMPUTE_A   = 3'd1;
localparam [2:0] COMPUTE_B   = 3'd2;
localparam [2:0] COMPUTE_DENOM = 3'd3;
localparam [2:0] COMPUTE_NUM = 3'd4;
localparam [2:0] DONE_STATE  = 3'd5;
localparam [2:0] MAX_STATES  = 3'd6;

// State registers
reg [2:0] state;
reg [2:0] next_state;

// Data registers
reg [9:0] int_part_reg;
reg [43:0] digits_packed_reg;
reg [3:0] L_reg;
reg [3:0] R_reg;
reg [3:0] K;          // L - R
reg [3:0] i;          // counter for A loop
reg [3:0] j;          // counter for B loop
reg [63:0] A;
reg [63:0] B;
reg [63:0] pow10_K;
reg [63:0] pow10_R;
reg [63:0] denom;
reg [63:0] num;
reg [2:0] cycle_count;  // To prevent infinite loops
localparam [2:0] MAX_CYCLES = 3'd50;

// Function to compute 10^n for n=0..11
function [63:0] pow10;
    input [3:0] n;
    begin
        case(n)
            4'd0: pow10 = 64'd1;
            4'd1: pow10 = 64'd10;
            4'd2: pow10 = 64'd100;
            4'd3: pow10 = 64'd1000;
            4'd4: pow10 = 64'd10000;
            4'd5: pow10 = 64'd100000;
            4'd6: pow10 = 64'd1000000;
            4'd7: pow10 = 64'd10000000;
            4'd8: pow10 = 64'd100000000;
            4'd9: pow10 = 64'd1000000000;
            4'd10: pow10 = 64'd10000000000;
            4'd11: pow10 = 64'd100000000000;
            default: pow10 = 64'd0;
        endcase
    end
endfunction

// Wire array for digits - using unpacked array for synthesis
wire [3:0] digit_0;
wire [3:0] digit_1;
wire [3:0] digit_2;
wire [3:0] digit_3;
wire [3:0] digit_4;
wire [3:0] digit_5;
wire [3:0] digit_6;
wire [3:0] digit_7;
wire [3:0] digit_8;
wire [3:0] digit_9;
wire [3:0] digit_10;

// Extract each 4-bit digit from packed input
// digit_0 is MSB (position 10), digit_10 is LSB (position 0)
assign digit_0 = digits_packed_reg[43:40];
assign digit_1 = digits_packed_reg[39:36];
assign digit_2 = digits_packed_reg[35:32];
assign digit_3 = digits_packed_reg[31:28];
assign digit_4 = digits_packed_reg[27:24];
assign digit_5 = digits_packed_reg[23:20];
assign digit_6 = digits_packed_reg[19:16];
assign digit_7 = digits_packed_reg[15:12];
assign digit_8 = digits_packed_reg[11:8];
assign digit_9 = digits_packed_reg[7:4];
assign digit_10 = digits_packed_reg[3:0];

// Next state logic
always @(*) begin
    next_state = state;
    case(state)
        IDLE: begin
            if (start) begin
                if (L_reg - R_reg == 4'd0)
                    next_state = COMPUTE_B;
                else
                    next_state = COMPUTE_A;
            end
        end
        COMPUTE_A: begin
            if (i < K)
                next_state = COMPUTE_A;
            else
                next_state = COMPUTE_B;
        end
        COMPUTE_B: begin
            if (j < R_reg)
                next_state = COMPUTE_B;
            else
                next_state = COMPUTE_DENOM;
        end
        COMPUTE_DENOM: begin
            next_state = COMPUTE_NUM;
        end
        COMPUTE_NUM: begin
            next_state = DONE_STATE;
        end
        DONE_STATE: begin
            next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Initialize all registers
        state <= IDLE;
        int_part_reg <= 10'd0;
        digits_packed_reg <= 44'd0;
        L_reg <= 4'd0;
        R_reg <= 4'd0;
        K <= 4'd0;
        i <= 4'd0;
        j <= 4'd0;
        A <= 64'd0;
        B <= 64'd0;
        pow10_K <= 64'd0;
        pow10_R <= 64'd0;
        denom <= 64'd0;
        num <= 64'd0;
        numerator <= 64'd0;
        denominator <= 64'd0;
        done <= 1'b0;
        cycle_count <= 3'd0;
    end else begin
        state <= next_state;
        cycle_count <= cycle_count + 3'd1;
        done <= 1'b0;
        
        case(state)
            IDLE: begin
                cycle_count <= 3'd0;
                if (start) begin
                    int_part_reg <= integer_part;
                    digits_packed_reg <= digits_packed;
                    L_reg <= L;
                    R_reg <= R;
                    K <= L - R;
                    pow10_K <= pow10(L - R);
                    pow10_R <= pow10(R);
                    i <= 4'd0;
                    j <= 4'd0;
                    A <= 64'd0;
                    B <= 64'd0;
                end
            end
            COMPUTE_A: begin
                if (i < K) begin
                    // Get digit at position i
                    case(i)
                        4'd0: A <= A * 64'd10 + {60'd0, digit_0};
                        4'd1: A <= A * 64'd10 + {60'd0, digit_1};
                        4'd2: A <= A * 64'd10 + {60'd0, digit_2};
                        4'd3: A <= A * 64'd10 + {60'd0, digit_3};
                        4'd4: A <= A * 64'd10 + {60'd0, digit_4};
                        4'd5: A <= A * 64'd10 + {60'd0, digit_5};
                        4'd6: A <= A * 64'd10 + {60'd0, digit_6};
                        4'd7: A <= A * 64'd10 + {60'd0, digit_7};
                        4'd8: A <= A * 64'd10 + {60'd0, digit_8};
                        4'd9: A <= A * 64'd10 + {60'd0, digit_9};
                        4'd10: A <= A * 64'd10 + {60'd0, digit_10};
                        default: A <= A;
                    endcase
                    i <= i + 1;
                end
            end
            COMPUTE_B: begin
                if (j < R_reg) begin
                    // Get digit at position K+j
                    case(K + j)
                        4'd0: B <= B * 64'd10 + {60'd0, digit_0};
                        4'd1: B <= B * 64'd10 + {60'd0, digit_1};
                        4'd2: B <= B * 64'd10 + {60'd0, digit_2};
                        4'd3: B <= B * 64'd10 + {60'd0, digit_3};
                        4'd4: B <= B * 64'd10 + {60'd0, digit_4};
                        4'd5: B <= B * 64'd10 + {60'd0, digit_5};
                        4'd6: B <= B * 64'd10 + {60'd0, digit_6};
                        4'd7: B <= B * 64'd10 + {60'd0, digit_7};
                        4'd8: B <= B * 64'd10 + {60'd0, digit_8};
                        4'd9: B <= B * 64'd10 + {60'd0, digit_9};
                        4'd10: B <= B * 64'd10 + {60'd0, digit_10};
                        default: B <= B;
                    endcase
                    j <= j + 1;
                end
            end
            COMPUTE_DENOM: begin
                // denom = 10^K * (10^R - 1)
                denom <= pow10_K * (pow10_R - 64'd1);
            end
            COMPUTE_NUM: begin
                // num = int_part * denom + (A * 10^R + B - A)
                num <= int_part_reg * denom + (A * pow10_R + B - A);
            end
            DONE_STATE: begin
                numerator <= num;
                denominator <= denom;
                done <= 1'b1;
            end
            default: begin
                state <= IDLE;
            end
        endcase
        
        // Safety check: prevent infinite loops
        if (cycle_count >= MAX_CYCLES) begin
            state <= IDLE;
            done <= 1'b1;
        end
    end
end

endmodule