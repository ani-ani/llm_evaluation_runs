module MathSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] m,
    input wire [3:0] n,
    input wire [7:0] p,
    input wire [7:0] q,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [15:0] candidate;
    reg [15:0] max_candidate;
    reg [15:0] power_10_mn;
    reg [15:0] power_10_n;
    reg [15:0] Y;
    reg [15:0] temp;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;
    
    // Compute powers of 10
    always @(*) begin
        // Compute 10^(m-1)
        case (m)
            4'd1: power_10_mn = 16'd1;
            4'd2: power_10_mn = 16'd10;
            4'd3: power_10_mn = 16'd100;
            4'd4: power_10_mn = 16'd1000;
            4'd5: power_10_mn = 16'd10000;
            4'd6: power_10_mn = 16'd100000;
            4'd7: power_10_mn = 16'd1000000;
            4'd8: power_10_mn = 16'd10000000;
            4'd9: power_10_mn = 16'd100000000;
            4'd10: power_10_mn = 16'd1000000000;
            4'd11: power_10_mn = 16'd10000000000;
            4'd12: power_10_mn = 16'd100000000000;
            4'd13: power_10_mn = 16'd1000000000000;
            4'd14: power_10_mn = 16'd10000000000000;
            4'd15: power_10_mn = 16'd100000000000000;
            4'd16: power_10_mn = 16'd1000000000000000;
            default: power_10_mn = 16'd1;
        endcase
        
        // Compute 10^n
        case (n)
            4'd0: power_10_n = 16'd1;
            4'd1: power_10_n = 16'd10;
            4'd2: power_10_n = 16'd100;
            4'd3: power_10_n = 16'd1000;
            4'd4: power_10_n = 16'd10000;
            default: power_10_n = 16'd1;
        endcase
        
        // Compute max candidate (10^m - 1)
        max_candidate = power_10_mn * 16'd10 - 16'd1;
        if (max_candidate > 16'd65535) begin
            max_candidate = 16'd65535;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            candidate <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        candidate <= power_10_mn;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute Y = candidate mod 10^(m-n)
                    Y = candidate % power_10_mn;
                    
                    // Compute temp = q * (Y * 10^n + p)
                    temp = Y * power_10_n + p;
                    temp = q * temp;
                    
                    // Check if candidate matches
                    if (candidate == temp) begin
                        result <= candidate;
                        state <= FINISH;
                    end else begin
                        // Increment candidate
                        candidate <= candidate + 16'd1;
                        
                        // Check if we've reached max candidate
                        if (candidate > max_candidate || cycle_count >= MAX_CYCLES) begin
                            result <= 16'd0;
                            state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule