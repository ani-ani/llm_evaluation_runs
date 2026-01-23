module bit_counter(
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in,
    output reg [3:0] result,
    output reg done
);
    
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COUNTING = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    reg [1:0] state;
    reg [3:0] count;
    reg [7:0] remaining;
    reg [3:0] bit_index;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            count <= 4'd0;
            remaining <= 8'd0;
            bit_index <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COUNTING;
                        count <= 4'd0;
                        remaining <= data_in;
                        bit_index <= 4'd0;
                    end
                end
                
                COUNTING: begin
                    count <= count + (remaining & 1'b1);
                    remaining <= remaining >> 1;
                    bit_index <= bit_index + 4'd1;
                    
                    if (bit_index == 4'd7) begin
                        state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    result <= count;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule