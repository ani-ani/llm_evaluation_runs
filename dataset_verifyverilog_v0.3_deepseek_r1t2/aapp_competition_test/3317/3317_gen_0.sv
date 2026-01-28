module lcp_calculator #(
    parameter STRING_LENGTH = 16,
    parameter DATA_WIDTH = 8,
    parameter INDEX_WIDTH = 4,
    parameter RESULT_WIDTH = 5
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [INDEX_WIDTH-1:0] i,
    input wire [INDEX_WIDTH-1:0] j,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

    reg [DATA_WIDTH-1:0] s [0:STRING_LENGTH-1];

    localparam [1:0]
        IDLE    = 2'd0,
        COMPARE = 2'd1,
        FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [INDEX_WIDTH-1:0] i_reg, j_reg;
    reg [RESULT_WIDTH-1:0] count;
    reg [RESULT_WIDTH-1:0] cycle_count;
    localparam [RESULT_WIDTH-1:0] MAX_CYCLES = RESULT_WIDTH\'(STRING_LENGTH);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= {RESULT_WIDTH{1'b0}};
            i_reg <= {INDEX_WIDTH{1'b0}};
            j_reg <= {INDEX_WIDTH{1'b0}};
            count <= {RESULT_WIDTH{1'b0}};
            cycle_count <= {RESULT_WIDTH{1'b0}};
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        i_reg <= i;
                        j_reg <= j;
                        count <= {RESULT_WIDTH{1'b0}};
                        cycle_count <= {RESULT_WIDTH{1'b0}};
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    cycle_count <= cycle_count + RESULT_WIDTH\'d1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else if ((i_reg < INDEX_WIDTH\'(STRING_LENGTH)) && 
                               (j_reg < INDEX_WIDTH\'(STRING_LENGTH)) && 
                               (s[i_reg] == s[j_reg])) begin
                        count <= count + RESULT_WIDTH\'d1;
                        i_reg <= i_reg + INDEX_WIDTH\'d1;
                        j_reg <= j_reg + INDEX_WIDTH\'d1;
                        state <= COMPARE;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= count;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule