module DanceComplexity(
    input clk,
    input rst_n,
    input start,
    input [99:0] x_value,
    input [6:0] n,
    output reg [31:0] ans,
    output reg done
);
    parameter [29:0] MOD = 30'd1000000007;
    
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_X_MOD = 3'd1;
    localparam [2:0] GET_POWER = 3'd2;
    localparam [2:0] MULTIPLY_ACCUM = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    reg [2:0] state;
    reg [29:0] x_mod_reg;
    reg [29:0] power;
    reg [29:0] remainder;
    reg [29:0] temp;
    reg [6:0] i;
    reg [4:0] j;
    
    reg [29:0] power_table [0:99];
    integer idx;
    
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
            
            for (idx = 0; idx < 100; idx = idx + 1) begin
                power_table[idx] <= (1 << idx) % MOD;
            end
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
                    x_mod_reg <= (x_mod_reg + x_mod_reg + x_value[i]) % MOD;
                    i <= i - 7'd1;
                    if (i == 7'd0) begin
                        state <= GET_POWER;
                    end
                end
                
                GET_POWER: begin
                    if (n > 7'd0) begin
                        power <= power_table[n - 7'd1];
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
                        remainder <= (remainder + temp) % MOD;
                    end
                    temp <= (temp + temp) % MOD;
                    j <= j + 5'd1;
                    if (j == 5'd29) begin
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    ans <= remainder;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule