module circular_shift (
    input clk,
    input rst_n,
    input start,
    input [15:0] x,
    input [3:0] shift,
    output reg [15:0] result,
    output reg done
);
    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] EXTRACT = 3'd1;
    localparam [2:0] CALC    = 3'd2;
    localparam [2:0] RECON   = 3'd3;
    localparam [2:0] FINISH  = 3'd4;
    
    reg [2:0] state, next_state;
    reg [15:0] x_reg;
    reg [3:0] shift_reg;
    reg [3:0] digits [0:3]; // 4 digits, each 4-bit (0-9)
    reg [3:0] shifted_digits [0:3];
    reg [1:0] i; // Counter for loops
    reg [3:0] k; // Effective shift
    
    // Cycle counter for fixed latency
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd10;
    
    // Control signals
    wire shift_is_zero;
    assign shift_is_zero = (shift_reg[1:0] == 2'd0);
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            x_reg <= 16'd0;
            shift_reg <= 4'd0;
            k <= 4'd0;
            cycle_count <= 4'd0;
            for (i = 0; i < 4; i = i + 1) begin
                digits[i] <= 4'd0;
                shifted_digits[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        x_reg <= x;
                        shift_reg <= shift;
                        state <= EXTRACT;
                    end
                end
                
                EXTRACT: begin
                    // Extract decimal digits from x_reg
                    // d0 = ones, d1 = tens, d2 = hundreds, d3 = thousands
                    digits[0] <= x_reg % 4'd10;
                    digits[1] <= (x_reg / 4'd10) % 4'd10;
                    digits[2] <= (x_reg / 4'd100) % 4'd10;
                    digits[3] <= (x_reg / 4'd1000) % 4'd10;
                    
                    // Calculate effective shift (shift % 4)
                    k <= shift_reg % 4'd4;
                    
                    state <= CALC;
                end
                
                CALC: begin
                    // Perform circular right shift by k
                    // If k == 0, copy as is
                    if (shift_is_zero) begin
                        for (i = 0; i < 4; i = i + 1) begin
                            shifted_digits[i] <= digits[i];
                        end
                    end else begin
                        // Circular shift logic
                        // shifted[i] = digits[(i + k) % 4]
                        // For right shift by k: new_index = (old_index + 4 - k) % 4
                        shifted_digits[0] <= digits[(4'd4 - k + 0) % 4'd4];
                        shifted_digits[1] <= digits[(4'd4 - k + 1) % 4'd4];
                        shifted_digits[2] <= digits[(4'd4 - k + 2) % 4'd4];
                        shifted_digits[3] <= digits[(4'd4 - k + 3) % 4'd4];
                    end
                    
                    state <= RECON;
                end
                
                RECON: begin
                    // Reconstruct integer from shifted digits
                    // result = d3*1000 + d2*100 + d1*10 + d0
                    result <= (shifted_digits[3] * 16'd1000) + 
                              (shifted_digits[2] * 16'd100) + 
                              (shifted_digits[1] * 16'd10) + 
                              shifted_digits[0];
                    
                    state <= FINISH;
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