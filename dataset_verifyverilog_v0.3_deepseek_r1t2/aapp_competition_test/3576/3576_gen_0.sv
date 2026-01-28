module evasion_probability #(
    parameter R_WIDTH = 8,
    parameter C_WIDTH = 8,
    parameter K_WIDTH = 8
) (
    input clk,
    input rst_n,
    input start,
    input [R_WIDTH-1:0] R,
    input [C_WIDTH-1:0] C,
    input [K_WIDTH-1:0] K,
    output reg [63:0] numerator,
    output reg [63:0] denominator,
    output reg valid
);
    
    // State machine states
    localparam [2:0] IDLE   = 3'd0;
    localparam [2:0] CALC_S = 3'd1;
    localparam [2:0] CALC_M = 3'd2;
    localparam [2:0] DONE   = 3'd3;
    
    reg [2:0] state;
    reg [63:0] S, M;
    reg [7:0] i, j;
    reg [63:0] term;
    reg [R_WIDTH-1:0] R_reg;
    reg [C_WIDTH-1:0] C_reg;
    reg [K_WIDTH-1:0] K_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            numerator <= 64'd0;
            denominator <= 64'd0;
            S <= 64'd0;
            M <= 64'd0;
            i <= 8'd0;
            j <= 8'd0;
            term <= 64'd0;
            R_reg <= {R_WIDTH{1'b0}};
            C_reg <= {C_WIDTH{1'b0}};
            K_reg <= {K_WIDTH{1'b0}};
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    i <= 8'd0;
                    j <= 8'd0;
                    S <= 64'd0;
                    if (start) begin
                        R_reg <= R;
                        C_reg <= C;
                        K_reg <= K;
                        state <= CALC_S;
                    end
                end
                
                CALC_S: begin
                    if (i <= (R_reg - R_WIDTH'd1) && i <= K_reg) begin
                        if (j <= (C_reg - C_WIDTH'd1) && (i + j) <= K_reg) begin
                            term = (64'(R_reg) - 64'(i)) * (64'(C_reg) - 64'(j));
                            if (i == 8'd0 && j == 8'd0) begin
                                S <= S + term;
                            end else if (i == 8'd0 || j == 8'd0) begin
                                S <= S + (term << 1);
                            end else begin
                                S <= S + (term << 2);
                            end
                            j <= j + 8'd1;
                        end else begin
                            j <= 8'd0;
                            i <= i + 8'd1;
                        end
                    end else begin
                        state <= CALC_M;
                    end
                end
                
                CALC_M: begin
                    M <= 64'(R_reg) * 64'(C_reg);
                    state <= DONE;
                end
                
                DONE: begin
                    numerator <= (M * M) - S;
                    denominator <= M * M;
                    valid <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule