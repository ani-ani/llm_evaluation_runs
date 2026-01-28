module interval_prime_checker(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] s1,
    input wire signed [7:0] e1,
    input wire signed [7:0] s2,
    input wire signed [7:0] e2,
    output reg [0:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    // Latch inputs
    reg signed [7:0] latched_s1, latched_e1;
    reg signed [7:0] latched_s2, latched_e2;

    // Compute intersection
    reg signed [7:0] intersect_start, intersect_end;
    reg [5:0] length;

    // Prime LUT (32 entries, 0-31)
    reg [0:0] prime_lut [0:31];
    
    // Initialize LUT
    initial begin
        // Non-prime (0)
        prime_lut[0] = 1'b0; prime_lut[1] = 1'b0; prime_lut[4] = 1'b0; prime_lut[6] = 1'b0;
        prime_lut[8] = 1'b0; prime_lut[9] = 1'b0; prime_lut[10] = 1'b0; prime_lut[12] = 1'b0;
        prime_lut[14] = 1'b0; prime_lut[15] = 1'b0; prime_lut[16] = 1'b0; prime_lut[18] = 1'b0;
        prime_lut[20] = 1'b0; prime_lut[21] = 1'b0; prime_lut[22] = 1'b0; prime_lut[24] = 1'b0;
        prime_lut[25] = 1'b0; prime_lut[26] = 1'b0; prime_lut[27] = 1'b0; prime_lut[28] = 1'b0;
        prime_lut[30] = 1'b0; prime_lut[31] = 1'b1; // 31 is prime
        
        // Prime (1)
        prime_lut[2] = 1'b1; prime_lut[3] = 1'b1; prime_lut[5] = 1'b1; prime_lut[7] = 1'b1;
        prime_lut[11] = 1'b1; prime_lut[13] = 1'b1; prime_lut[17] = 1'b1; prime_lut[19] = 1'b1;
        prime_lut[23] = 1'b1; prime_lut[29] = 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            latched_s1 <= 8'd0;
            latched_e1 <= 8'd0;
            latched_s2 <= 8'd0;
            latched_e2 <= 8'd0;
            intersect_start <= 8'd0;
            intersect_end <= 8'd0;
            length <= 6'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        latched_s1 <= s1;
                        latched_e1 <= e1;
                        latched_s2 <= s2;
                        latched_e2 <= e2;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute intersection
                    intersect_start <= (latched_s1 > latched_s2) ? latched_s1 : latched_s2;
                    intersect_end <= (latched_e1 < latched_e2) ? latched_e1 : latched_e2;
                    
                    // Compute length
                    if (intersect_start > intersect_end) begin
                        length <= 6'd0;
                    end else begin
                        length <= intersect_end - intersect_start;
                    end
                    
                    // Prime check
                    if (length == 6'd32) begin
                        result <= 1'b0; // 32 is not prime
                    end else begin
                        result <= prime_lut[length];
                    end
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
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