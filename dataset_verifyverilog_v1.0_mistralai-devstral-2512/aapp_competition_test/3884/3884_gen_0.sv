module FuelCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] a_i [0:999],
    input wire [9:0] b_i [0:999],
    input wire [9:0] m,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] CALCULATE = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd100000;

    // Internal registers
    reg [31:0] product_accum;
    reg [31:0] temp_a, temp_b;
    reg [31:0] a_fixed, b_fixed;
    reg [31:0] a_minus_1, b_minus_1;
    reg [31:0] a_ratio, b_ratio;
    reg [31:0] m_extended;
    reg [31:0] final_result;
    
    integer i;
    reg [9:0] current_a, current_b;
    reg impossible;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            product_accum <= 32'd65536;  // Q16.16 representation of 1.0
            impossible <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    cycle_count <= cycle_count + 16'd1;
                    impossible <= 1'b0;
                    
                    // Check if any a_i or b_i equals 1
                    for (i = 0; i < 1000; i = i + 1) begin
                        if (a_i[i] == 10'd1 || b_i[i] == 10'd1) begin
                            impossible <= 1'b1;
                        end
                    end
                    
                    if (impossible) begin
                        state <= FINISH;
                    end else begin
                        state <= CALCULATE;
                    end
                end
                
                CALCULATE: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Initialize product accumulator to 1.0 in Q16.16
                    product_accum <= 32'd65536;
                    
                    // Calculate product of (a_i/(a_i-1)) * (b_i/(b_i-1)) for all planets
                    for (i = 0; i < 1000; i = i + 1) begin
                        current_a <= a_i[i];
                        current_b <= b_i[i];
                        
                        // Calculate a_i/(a_i-1) in Q16.16
                        a_minus_1 <= {16'd0, current_a} - 32'd1;
                        a_ratio <= (32'd65536 << 16) / a_minus_1;
                        
                        // Calculate b_i/(b_i-1) in Q16.16
                        b_minus_1 <= {16'd0, current_b} - 32'd1;
                        b_ratio <= (32'd65536 << 16) / b_minus_1;
                        
                        // Multiply ratios (Q16.16 * Q16.16 = Q32.32, take upper 32 bits)
                        temp_a <= a_ratio * b_ratio;
                        product_accum <= (product_accum * temp_a) >> 16;
                    end
                    
                    // Calculate final result: m * product - m
                    m_extended <= {16'd0, m};
                    final_result <= (m_extended * product_accum) - m_extended;
                    
                    state <= FINISH;
                end
                
                FINISH: begin
                    if (impossible) begin
                        result <= 32'hFFFFFFFF;  // -1 in Q16.16
                    end else begin
                        result <= final_result;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule