module difference_calculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] n,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state, next_state;
    
    // Combinational calculation registers
    reg [31:0] s_reg;
    reg [31:0] result_comb;
    
    // State transition logic (combinational)
    always @(*) begin
        case (state)
            IDLE: next_state = start ? COMPUTE : IDLE;
            COMPUTE: next_state = FINISH;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            s_reg <= 32'd0;
            result_comb <= 32'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Calculate S = n*(n+1)/2 using combinational logic
                        // n is 6-bit, so n+1 fits in 7 bits
                        // n*(n+1) fits in 13 bits
                        s_reg <= ({26'd0, n} * ({26'd0, n} + 32'd1)) >> 1;
                    end
                end
                
                COMPUTE: begin
                    // Calculate result = S*(S-1)
                    result_comb <= s_reg * (s_reg - 32'd1);
                end
                
                FINISH: begin
                    result <= result_comb;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule