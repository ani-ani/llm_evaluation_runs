module polite_number(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] STAGE1 = 2'd1;
    localparam [1:0] STAGE2 = 2'd2;
    
    reg [1:0] state;
    reg [7:0] log2_result;
    reg [15:0] sum_result;
    
    // Priority encoder for floor(log2(n))
    always @(*) begin
        if (n == 8'd0) begin
            log2_result = 8'd0;
        end else begin
            if (n[7]) log2_result = 8'd7;
            else if (n[6]) log2_result = 8'd6;
            else if (n[5]) log2_result = 8'd5;
            else if (n[4]) log2_result = 8'd4;
            else if (n[3]) log2_result = 8'd3;
            else if (n[2]) log2_result = 8'd2;
            else if (n[1]) log2_result = 8'd1;
            else log2_result = 8'd0;
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            log2_result <= 8'd0;
            sum_result <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= STAGE1;
                    end
                end
                
                STAGE1: begin
                    state <= STAGE2;
                end
                
                STAGE2: begin
                    sum_result <= {1'b0, n} + {8'b0, log2_result} + 16'd1;
                    result <= sum_result;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule