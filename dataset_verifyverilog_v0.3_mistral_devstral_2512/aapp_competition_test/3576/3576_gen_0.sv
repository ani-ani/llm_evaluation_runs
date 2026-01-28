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
reg [2:0] state;
localparam [2:0] IDLE = 3'd0;
localparam [2:0] CALC_S = 3'd1;
localparam [2:0] CALC_M = 3'd2;
localparam [2:0] DONE = 3'd3;

// Internal registers
reg [63:0] S, M;
reg [7:0] i, j;
reg [63:0] term;
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd1000;

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
        cycle_count <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                valid <= 1'b0;
                if (start) begin
                    S <= 64'd0;
                    i <= 8'd0;
                    j <= 8'd0;
                    cycle_count <= 8'd0;
                    state <= CALC_S;
                end
            end
            
            CALC_S: begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    state <= DONE;
                end else if (i <= R-1 && i <= K) begin
                    if (j <= C-1 && i + j <= K) begin
                        term = (R - i) * (C - j);
                        if (i == 0 && j == 0) begin
                            S <= S + term;
                        end else if (i == 0 || j == 0) begin
                            S <= S + 2 * term;
                        end else begin
                            S <= S + 4 * term;
                        end
                        j <= j + 1;
                    end else begin
                        j <= 0;
                        i <= i + 1;
                    end
                end else begin
                    state <= CALC_M;
                end
            end
            
            CALC_M: begin
                M <= R * C;
                state <= DONE;
            end
            
            DONE: begin
                numerator <= (M * M) - S;
                denominator <= M * M;
                valid <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule