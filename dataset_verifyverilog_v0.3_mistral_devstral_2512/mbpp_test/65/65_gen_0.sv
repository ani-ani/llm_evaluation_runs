module RecursiveListSumFlattener(
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in,
    input valid_in,
    input [1:0] depth_in,
    output reg [15:0] result,
    output reg done,
    output reg ready
);

    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] PROCESS = 4'd1;
    localparam [3:0] FINISH = 4'd2;
    
    localparam [3:0] MAX_ELEMENTS = 4'd16;
    
    reg [3:0] state;
    reg [3:0] element_count;
    reg [15:0] accumulator;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            element_count <= 4'd0;
            accumulator <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            ready <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    ready <= 1'b1;
                    if (start) begin
                        state <= PROCESS;
                        ready <= 1'b0;
                        element_count <= 4'd0;
                        accumulator <= 16'd0;
                    end
                end
                
                PROCESS: begin
                    ready <= 1'b0;
                    if (valid_in) begin
                        if (depth_in >= 2'd1) begin
                            accumulator <= accumulator + {8'd0, data_in};
                        end
                        element_count <= element_count + 4'd1;
                        if (element_count >= MAX_ELEMENTS) begin
                            state <= FINISH;
                        end
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= accumulator;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    ready <= 1'b1;
                    done <= 1'b0;
                    result <= 16'd0;
                end
            endcase
        end
    end

endmodule