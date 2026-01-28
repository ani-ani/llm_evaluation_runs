module remove_whitespace (
    input clk,
    input rst_n,
    input start,
    input [7:0] input_str [0:15],
    input [3:0] length,
    output reg [7:0] output_str [0:15],
    output reg [3:0] output_len,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] READ_INPUT = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    // Whitespace character constants
    localparam [7:0] SPACE = 8'h20;
    localparam [7:0] TAB = 8'h09;
    localparam [7:0] LF = 8'h0A;
    localparam [7:0] CR = 8'h0D;
    
    // Internal registers
    reg [1:0] state;
    reg [3:0] input_idx;
    reg [3:0] output_idx;
    reg [7:0] temp_buffer [0:15];
    reg [3:0] temp_len;
    reg is_whitespace;
    integer i;
    
    // Check if current byte is whitespace
    always @(*) begin
        is_whitespace = 1'b0;
        if (input_str[input_idx] == SPACE ||
            input_str[input_idx] == TAB ||
            input_str[input_idx] == LF ||
            input_str[input_idx] == CR) begin
            is_whitespace = 1'b1;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            input_idx <= 4'd0;
            output_idx <= 4'd0;
            output_len <= 4'd0;
            temp_len <= 4'd0;
            done <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                output_str[i] <= 8'd0;
                temp_buffer[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    input_idx <= 4'd0;
                    output_idx <= 4'd0;
                    temp_len <= 4'd0;
                    if (start) begin
                        // Clear output array
                        for (i = 0; i < 16; i = i + 1) begin
                            output_str[i] <= 8'd0;
                        end
                        state <= READ_INPUT;
                    end
                end
                
                READ_INPUT: begin
                    // Process each character
                    if (input_idx < length) begin
                        if (!is_whitespace) begin
                            // Store non-whitespace character
                            temp_buffer[temp_len] <= input_str[input_idx];
                            temp_len <= temp_len + 4'd1;
                        end
                        input_idx <= input_idx + 4'd1;
                    end else begin
                        // Done reading input, copy to output
                        output_len <= temp_len;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < temp_len) begin
                                output_str[i] <= temp_buffer[i];
                            end else begin
                                output_str[i] <= 8'd0;
                            end
                        end
                        state <= COMPLETE;
                    end
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