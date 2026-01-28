module CenteredHexagonalNumber(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] STAGE1  = 2'd1;
    localparam [1:0] STAGE2  = 2'd2;
    localparam [1:0] STAGE3  = 2'd3;
    
    reg [1:0] state;
    reg [7:0] n_minus_1;
    reg [15:0] temp;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            n_minus_1 <= 8'd0;
            temp <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= STAGE1;
                    end
                end
                
                STAGE1: begin
                    cycle_count <= cycle_count + 8'd1;
                    n_minus_1 <= n - 8'd1;
                    state <= STAGE2;
                end
                
                STAGE2: begin
                    cycle_count <= cycle_count + 8'd1;
                    temp <= 16'($signed(3'd3) * $signed(n) * $signed(n_minus_1));
                    state <= STAGE3;
                end
                
                STAGE3: begin
                    cycle_count <= cycle_count + 8'd1;
                    result <= temp + 16'd1;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule