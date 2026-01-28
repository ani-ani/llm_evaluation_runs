module TupleAppender(
    input clk,
    input rst_n,
    input start,
    input [7:0] list_in [0:15],
    input [7:0] tuple_in [0:7],
    input [3:0] list_len,
    input [2:0] tuple_len,
    output reg [7:0] result [0:15],
    output reg [3:0] result_len,
    output reg done,
    output reg overflow
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd16;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            overflow <= 1'b0;
            result_len <= 4'd0;
            cycle_count <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    overflow <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Copy list_in to result
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < list_len) begin
                            result[i] <= list_in[i];
                        end else begin
                            result[i] <= 8'd0;
                        end
                    end
                    
                    // Append tuple_in to result
                    for (i = 0; i < tuple_len; i = i + 1) begin
                        if ((list_len + i) < 16) begin
                            result[list_len + i] <= tuple_in[i];
                        end
                    end
                    
                    // Calculate new length
                    result_len <= list_len + tuple_len;
                    
                    // Check for overflow
                    if (result_len > 16) begin
                        overflow <= 1'b1;
                        result_len <= 4'd16;
                    end else begin
                        overflow <= 1'b0;
                    end
                    
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule