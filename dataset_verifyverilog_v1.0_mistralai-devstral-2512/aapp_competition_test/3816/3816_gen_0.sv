module TriangleCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] a,
    input wire [15:0] b,
    input wire [15:0] c,
    input wire [7:0] l,
    output reg [63:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Intermediate registers
    reg [63:0] total_combinations;
    reg [63:0] violating_combinations;
    reg [63:0] temp_result;
    
    reg [15:0] s_ab, s_bc, s_ca;
    reg [7:0] x, k;
    reg [15:0] min_val;
    reg [63:0] comb_calc;

    // Compute combination C(n,2) = n*(n+1)/2
    function [63:0] compute_c2;
        input [15:0] n;
        begin
            compute_c2 = (n * (n + 16'd1)) / 16'd2;
        end
    endfunction

    // Compute combination C(n,3) = n*(n+1)*(n+2)/6
    function [63:0] compute_c3;
        input [15:0] n;
        begin
            compute_c3 = (n * (n + 16'd1) * (n + 16'd2)) / 16'd6;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 64'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            total_combinations <= 64'd0;
            violating_combinations <= 64'd0;
            temp_result <= 64'd0;
            s_ab <= 16'd0;
            s_bc <= 16'd0;
            s_ca <= 16'd0;
            x <= 8'd0;
            k <= 8'd0;
            min_val <= 16'd0;
            comb_calc <= 64'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate s values for each permutation
                    s_ab <= a - b - c;
                    s_bc <= b - a - c;
                    s_ca <= c - a - b;
                    
                    // Calculate total combinations
                    total_combinations <= compute_c3(l + 16'd3);
                    
                    // Reset violating combinations counter
                    violating_combinations <= 64'd0;
                    
                    // Process first permutation (a as the first stick)
                    for (x = 0; x <= l; x = x + 1) begin
                        min_val <= (s_ab + x) < (l - x) ? (s_ab + x) : (l - x);
                        if (min_val >= 0) begin
                            violating_combinations <= violating_combinations + compute_c2(min_val + 16'd2);
                        end
                    end
                    
                    // Process second permutation (b as the first stick)
                    for (x = 0; x <= l; x = x + 1) begin
                        min_val <= (s_bc + x) < (l - x) ? (s_bc + x) : (l - x);
                        if (min_val >= 0) begin
                            violating_combinations <= violating_combinations + compute_c2(min_val + 16'd2);
                        end
                    end
                    
                    // Process third permutation (c as the first stick)
                    for (x = 0; x <= l; x = x + 1) begin
                        min_val <= (s_ca + x) < (l - x) ? (s_ca + x) : (l - x);
                        if (min_val >= 0) begin
                            violating_combinations <= violating_combinations + compute_c2(min_val + 16'd2);
                        end
                    end
                    
                    // Calculate final result
                    temp_result <= total_combinations - violating_combinations;
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= temp_result;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule