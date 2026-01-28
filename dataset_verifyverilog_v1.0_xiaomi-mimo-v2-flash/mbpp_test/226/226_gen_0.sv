module odd_index_filter (
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [7:0] input_str [0:15],
    output reg [7:0] result [0:7],
    output reg [3:0] output_len,
    output reg done
);
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE = 2'd2;
    
    reg [1:0] state;
    reg [3:0] idx;
    reg [3:0] out_idx;
    reg [3:0] current_len;
    reg [7:0] temp_input_str [0:15];
    reg [1:0] delay_counter;
    localparam [1:0] MAX_DELAY = 2'd2;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            output_len <= 4'd0;
            idx <= 4'd0;
            out_idx <= 4'd0;
            current_len <= 4'd0;
            delay_counter <= 2'd0;
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 8'd0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                temp_input_str[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    delay_counter <= 2'd0;
                    if (start) begin
                        current_len <= len;
                        idx <= 4'd0;
                        out_idx <= 4'd0;
                        output_len <= 4'd0;
                        for (i = 0; i < 8; i = i + 1) begin
                            result[i] <= 8'd0;
                        end
                        for (i = 0; i < 16; i = i + 1) begin
                            temp_input_str[i] <= input_str[i];
                        end
                        state <= PROCESSING;
                    end
                end
                
                PROCESSING: begin
                    if (idx < current_len) begin
                        if (idx[0] == 1'b0) begin // Even index check
                            if (out_idx < 4'd8) begin
                                result[out_idx] <= temp_input_str[idx];
                                out_idx <= out_idx + 4'd1;
                            end
                        end
                        idx <= idx + 4'd1;
                    end else begin
                        // All characters processed
                        delay_counter <= delay_counter + 2'd1;
                        if (delay_counter >= MAX_DELAY) begin
                            output_len <= out_idx;
                            done <= 1'b1;
                            state <= DONE;
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule