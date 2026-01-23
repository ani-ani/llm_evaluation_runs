module bracket_converter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [3:0] char_valid,
    output reg [63:0] result,
    output reg [3:0] result_len,
    output reg done,
    output reg error
);

    // States
    localparam S_IDLE = 2'b00;
    localparam S_READ = 2'b01;
    localparam S_PROCESS = 2'b10;
    localparam S_DONE = 2'b11;

    reg [1:0] state;
    reg [2:0] sp; // Stack pointer
    reg [2:0] stack[0:7];
    reg [2:0] rd_ptr;
    reg [2:0] wr_ptr;
    reg [7:0] buffer[0:7];
    reg [3:0] out_bytes;
    reg [5:0] latency;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            result <= 64'd0;
            result_len <= 4'd0;
            done <= 1'b0;
            error <= 1'b0;
            sp <= 3'd0;
            rd_ptr <= 3'd0;
            wr_ptr <= 3'd0;
            out_bytes <= 4'd0;
            latency <= 6'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    sp <= 3'd0;
                    rd_ptr <= 3'd0;
                    wr_ptr <= 3'd0;
                    out_bytes <= 4'd0;
                    latency <= 6'd0;
                    result_len <= 4'd0;
                    result <= 64'd0;
                    
                    if (start && char_valid[0]) begin
                        if (char_in == 8'h28 || char_in == 8'h29) begin
                            buffer[0] <= char_in;
                            wr_ptr <= 3'd1;
                            state <= S_READ;
                        end else begin
                            error <= 1'b1;
                            done <= 1'b1;
                        end
                    end
                end

                S_READ: begin
                    if (char_valid[0] && wr_ptr < 8) begin
                        if (char_in == 8'h28 || char_in == 8'h29) begin
                            buffer[wr_ptr] <= char_in;
                            wr_ptr <= wr_ptr + 1;
                        end else if (char_in == 8'h00) begin
                            // Null terminator, stop reading
                        end else begin
                            error <= 1'b1;
                            state <= S_IDLE;
                            done <= 1'b1;
                        end
                    end
                    
                    // Transition to process
                    if ((!char_valid[0] && start) || wr_ptr >= 8) begin
                        state <= S_PROCESS;
                    end
                    if (char_valid[0] && char_in == 8'h00) state <= S_PROCESS;
                end

                S_PROCESS: begin
                    if (rd_ptr < wr_ptr) begin
                        if (buffer[rd_ptr] == 8'h28) begin // '('
                            if (sp < 8) begin
                                stack[sp] <= rd_ptr;
                                sp <= sp + 1;
                            end else begin
                                error <= 1'b1;
                                state <= S_IDLE;
                                done <= 1'b1;
                            end
                        end else begin // ')'
                            if (sp > 0) begin
                                sp <= sp - 1;
                                if (out_bytes + 5 <= 8) begin
                                    // Write header: Start, ',', End, ':', Null
                                    // Using ASCII conversion: '0' + index
                                    // indices are 0-7, mapped to ASCII 48-55
                                    result[out_bytes*8 +: 8] <= 8'h30 + stack[sp-1]; // Start index
                                    result[(out_bytes+1)*8 +: 8] <= 8'h2C;           // ','
                                    result[(out_bytes+2)*8 +: 8] <= 8'h30 + rd_ptr;  // End index
                                    result[(out_bytes+3)*8 +: 8] <= 8'h3A;           // ':'
                                    result[(out_bytes+4)*8 +: 8] <= 8'h00;           // Null
                                    out_bytes <= out_bytes + 5;
                                end else begin
                                    error <= 1'b1;
                                    state <= S_IDLE;
                                    done <= 1'b1;
                                end
                            end else begin
                                error <= 1'b1;
                                state <= S_IDLE;
                                done <= 1'b1;
                            end
                        end
                        rd_ptr <= rd_ptr + 1;
                    end else begin
                        // End of buffer
                        if (sp != 0) begin // Unbalanced
                            error <= 1'b1;
                            done <= 1'b1;
                            state <= S_IDLE;
                        end else begin
                            result_len <= out_bytes;
                            state <= S_DONE;
                        end
                    end
                end

                S_DONE: begin
                    latency <= latency + 1;
                    if (latency >= 50) begin
                        done <= 1'b1;
                        state <= S_IDLE;
                    end
                end
            endcase
        end
    end
endmodule