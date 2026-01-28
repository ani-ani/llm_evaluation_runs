module DecagonalNumberCalc(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] STAGE1  = 3'd1;  // Compute n_squared
    localparam [2:0] STAGE2  = 3'd2;  // Compute 4*n_squared
    localparam [2:0] STAGE3  = 3'd3;  // Compute 3*n
    localparam [2:0] DONE    = 3'd4;
    
    reg [2:0] state;
    reg [15:0] n_squared_reg;
    reg [15:0] n4_reg;  // 4*n_squared
    reg [9:0] n3_reg;   // 3*n (max 765)
    reg overflow_detected;
    
    // Intermediate wires for combinational logic
    wire [15:0] n_squared;
    wire [17:0] n4_intermediate;
    wire [15:0] n4_clamped;
    wire [9:0] n3;
    wire [16:0] diff_temp;
    wire [15:0] diff_result;
    wire result_overflow;
    
    // Combinational calculations (registered in next stage)
    assign n_squared = n * n;  // 8x8 = 16 bits
    assign n4_intermediate = n_squared_reg << 2;  // 16-bit shift left 2 = 18 bits
    assign n4_clamped = (n4_intermediate[17:16] != 2'd0) ? 16'd65535 : n4_intermediate[15:0];
    assign n3 = (n << 1) + n;  // 2*n + n = 3*n
    assign diff_temp = {1'b0, n4_reg} - {6'd0, n3_reg};  // 17-bit subtraction
    assign diff_result = diff_temp[15:0];  // Lower 16 bits
    assign result_overflow = diff_temp[16] || (diff_temp > 16'd65535);
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            n_squared_reg <= 16'd0;
            n4_reg <= 16'd0;
            n3_reg <= 10'd0;
            overflow_detected <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    overflow_detected <= 1'b0;
                    if (start) begin
                        state <= STAGE1;
                    end
                end
                
                STAGE1: begin
                    // Compute n_squared = n * n
                    n_squared_reg <= n_squared;
                    state <= STAGE2;
                end
                
                STAGE2: begin
                    // Compute 4*n_squared and check for overflow
                    n4_reg <= n4_clamped;
                    if (n4_intermediate[17:16] != 2'd0) begin
                        overflow_detected <= 1'b1;
                    end
                    state <= STAGE3;
                end
                
                STAGE3: begin
                    // Compute 3*n
                    n3_reg <= n3;
                    state <= DONE;
                end
                
                DONE: begin
                    // Compute final result
                    if (overflow_detected || result_overflow) begin
                        result <= 16'd65535;  // Clamp to max
                    end else begin
                        result <= diff_result;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule