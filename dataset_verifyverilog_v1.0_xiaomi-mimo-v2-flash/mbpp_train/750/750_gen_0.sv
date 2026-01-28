module AppendTuple (
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

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE  = 3'd1;
    localparam [2:0] FINISH   = 3'd2;
    
    reg [2:0] state;
    reg [3:0] i;
    reg [3:0] tuple_idx;
    reg [3:0] max_len;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            overflow <= 1'b0;
            result_len <= 4'd0;
            // Initialize result array
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    overflow <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Calculate total length and overflow
                    if (list_len + tuple_len > 16) begin
                        overflow <= 1'b1;
                        result_len <= 4'd16;
                        max_len <= 4'd16;
                    end else begin
                        overflow <= 1'b0;
                        result_len <= list_len + tuple_len;
                        max_len <= list_len + tuple_len;
                    end
                    
                    // Copy list_in to result
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < list_len) begin
                            result[i] <= list_in[i];
                        end
                    end
                    
                    // Append tuple_in to result
                    for (tuple_idx = 0; tuple_idx < 8; tuple_idx = tuple_idx + 1) begin
                        if (tuple_idx < tuple_len && (list_len + tuple_idx) < 16) begin
                            result[list_len + tuple_idx] <= tuple_in[tuple_idx];
                        end
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