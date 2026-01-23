module DanceComplexity(
    input clk,
    input rst_n,
    input start,
    input [99:0] x_value,
    input [6:0] n,
    output reg [31:0] ans,
    output reg done
);
    
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE_X_MOD = 2'd1;
    localparam [1:0] GET_POWER = 2'd2;
    localparam [1:0] MULTIPLY_ACCUM = 2'd3;
    localparam [1:0] FINISH = 2'd4;
    
    // State register
    reg [1:0] state;
    
    // Working registers
    reg [29:0] x_mod_reg;
    reg [29:0] power;
    reg [29:0] remainder;
    reg [29:0] temp;
    
    // Counters
    reg [6:0] i;
    reg [4:0] j;
    
    // Precomputed power table: 2^(0) to 2^(99) mod MOD
    reg [29:0] power_table [0:99];
    
    // Initialize power_table
    integer idx;
    initial begin
        for (idx = 0; idx < 100; idx = idx + 1) begin
            power_table[idx] = (1 << idx) % 1000000007;
        end
    end
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            ans <= 32'd0;
            x_mod_reg <= 30'd0;
            power <= 30'd0;
            remainder <= 30'd0;
            temp <= 30'd0;
            i <= 7'd0;
            j <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE_X_MOD;
                        x_mod_reg <= 30'd0;
                        i <= 7'd99;
                    end
                end
                
                COMPUTE_X_MOD: begin
                    x_mod_reg <= (x_mod_reg + x_mod_reg + x_value[i]) % 1000000007;
                    i <= i - 1'b1;
                    if (i == 7'd0) begin
                        state <= GET_POWER;
                    end
                end
                
                GET_POWER: begin
                    if (n > 7'd0) begin
                        power <= power_table[n - 1'b1];
                    end else begin
                        power <= 30'd0;
                    end
                    state <= MULTIPLY_ACCUM;
                    j <= 5'd0;
                    remainder <= 30'd0;
                    temp <= x_mod_reg;
                end
                
                MULTIPLY_ACCUM: begin
                    if (power[j]) begin
                        remainder <= (remainder + temp) % 1000000007;
                    end
                    temp <= (temp + temp) % 1000000007;
                    j <= j + 1'b1;
                    if (j == 5'd29) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    ans <= remainder;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule