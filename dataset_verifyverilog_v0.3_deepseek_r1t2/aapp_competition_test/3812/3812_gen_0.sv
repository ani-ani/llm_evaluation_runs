module StringMatcher(
    input clk,
    input rst_n,
    input start,
    input [3:0] s_len,
    input [3:0] t_len,
    input [15:0] s_data,
    input [15:0] t_data,
    output reg done,
    output reg [3:0] op_count,
    output reg [15:0] operations
);
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCAN = 2'd1;
    localparam [1:0] SWAP = 2'd2;
    localparam [1:0] COMPLETE = 2'd3;
    
    wire [3:0] min_len = (s_len < t_len) ? s_len : t_len;
    
    reg [1:0] state;
    reg [3:0] current_index;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            op_count <= 4'd0;
            operations <= 16'd0;
            current_index <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    op_count <= 4'd0;
                    operations <= 16'd0;
                    current_index <= 4'd0;
                    if (start) state <= SCAN;
                end
                
                SCAN: begin
                    if (current_index < min_len) begin
                        if (s_data[current_index] != t_data[current_index]) begin
                            state <= SWAP;
                        end else begin
                            current_index <= current_index + 4'd1;
                        end
                    end else begin
                        state <= COMPLETE;
                    end
                end
                
                SWAP: begin
                    op_count <= op_count + 4'd1;
                    if (op_count < 4'd8) begin
                        operations <= (operations << 2) | 2'b01;
                    end
                    current_index <= current_index + 4'd1;
                    state <= SCAN;
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule