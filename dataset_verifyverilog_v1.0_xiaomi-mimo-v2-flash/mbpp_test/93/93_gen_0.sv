module power_calc (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] a,
    input wire [3:0] b,
    output reg [15:0] result,
    output reg done,
    output reg overflow
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALCULATING = 2'd1;
    localparam [1:0] DONE = 2'd2;
    
    // Internal registers
    reg [1:0] state_r;
    reg [3:0] counter_r;
    reg [7:0] base_r;
    reg [15:0] result_r;
    reg [3:0] exp_r;
    reg overflow_r;
    
    // Overflow detection: check if result * base > 65535
    // Since base is 8-bit, max result without overflow is 65535/255 ≈ 257
    // But for safety, we check: result_r * base_r > 65535
    wire [23:0] mult_temp;  // 16 + 8 = 24 bits
    wire overflow_detect;
    
    assign mult_temp = {8'd0, result_r} * {16'd0, base_r};
    assign overflow_detect = (mult_temp[23:16] != 8'd0);  // Check if upper bits non-zero
    
    // Combinational multiplication result
    wire [15:0] next_result;
    assign next_result = result_r * base_r;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r <= IDLE;
            counter_r <= 4'd0;
            base_r <= 8'd0;
            result_r <= 16'd0;
            exp_r <= 4'd0;
            overflow_r <= 1'b0;
            result <= 16'd0;
            done <= 1'b0;
            overflow <= 1'b0;
        end else begin
            case (state_r)
                IDLE: begin
                    done <= 1'b0;
                    overflow <= 1'b0;
                    if (start) begin
                        // Initialize based on exponent value
                        base_r <= a;
                        exp_r <= b;
                        counter_r <= 4'd0;
                        overflow_r <= 1'b0;
                        
                        if (b == 4'd0) begin
                            // a^0 = 1 (unless a=0, which is handled later)
                            result_r <= 16'd1;
                            if (a == 8'd0) begin
                                result_r <= 16'd0;
                            end
                            state_r <= DONE;
                        end else if (a == 8'd0) begin
                            // 0^b = 0 for b > 0
                            result_r <= 16'd0;
                            state_r <= DONE;
                        end else begin
                            // Normal case: a^b where a>0 and b>0
                            result_r <= a;  // Start with a^1
                            counter_r <= 4'd1;  // Already done 1 multiplication
                            state_r <= CALCULATING;
                        end
                    end
                end
                
                CALCULATING: begin
                    // Check if we've done all multiplications
                    if (counter_r >= exp_r) begin
                        // Done calculating
                        result <= result_r;
                        overflow <= overflow_r;
                        state_r <= DONE;
                    end else begin
                        // Perform multiplication and check overflow
                        if (overflow_detect) begin
                            // Overflow detected
                            overflow_r <= 1'b1;
                            result_r <= 16'd65535;  // Saturate
                            // Skip remaining multiplications
                            state_r <= DONE;
                        end else begin
                            result_r <= next_result;
                            counter_r <= counter_r + 4'd1;
                            // Stay in CALCULATING state
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state_r <= IDLE;
                end
                
                default: state_r <= IDLE;
            endcase
        end
    end

endmodule