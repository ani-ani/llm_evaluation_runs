module all_prefixes (
    input clk,
    input rst_n,
    input start,
    input [7:0] str [0:7],
    input [3:0] len,
    output reg [7:0] prefix [0:7],
    output reg [3:0] prefix_len,
    output reg valid,
    output reg done
);
    
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state;
    reg [7:0] stored_str [0:7];
    reg [3:0] stored_len;
    reg [3:0] current_len;
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            done <= 1'b0;
            prefix_len <= 4'd0;
            current_len <= 4'd0;
            stored_len <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                stored_str[i] <= 8'd0;
                prefix[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            stored_str[i] <= str[i];
                        end
                        stored_len <= len;
                        if (len != 4'd0) begin
                            current_len <= 4'd1;
                            state <= PROCESSING;
                        end else begin
                            done <= 1'b1;
                            state <= DONE_STATE;
                        end
                    end
                end
                
                PROCESSING: begin
                    valid <= 1'b1;
                    prefix_len <= current_len;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < current_len) begin
                            prefix[i] <= stored_str[i];
                        end else begin
                            prefix[i] <= 8'd0;
                        end
                    end
                    
                    if (current_len == stored_len) begin
                        state <= DONE_STATE;
                        current_len <= 4'd0;
                    end else begin
                        current_len <= current_len + 4'd1;
                    end
                end
                
                DONE_STATE: begin
                    valid <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule