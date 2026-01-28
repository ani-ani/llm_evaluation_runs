module remove_odd (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    input wire [3:0] len,
    output reg [7:0] out_0, out_1, out_2, out_3, out_4, out_5, out_6, out_7,
    output reg [3:0] out_len,
    output reg done
);

    // State machine states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    reg [1:0] state, next_state;
    reg [3:0] idx;
    reg [3:0] write_idx;
    
    // Input buffer
    reg [7:0] buffer [0:7];
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = PROCESS;
                else next_state = IDLE;
            end
            PROCESS: begin
                if (idx >= len) next_state = COMPLETE;
                else next_state = PROCESS;
            end
            COMPLETE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 4'd0;
            write_idx <= 4'd0;
            out_len <= 4'd0;
            done <= 1'b0;
            out_0 <= 8'd0; out_1 <= 8'd0; out_2 <= 8'd0; out_3 <= 8'd0;
            out_4 <= 8'd0; out_5 <= 8'd0; out_6 <= 8'd0; out_7 <= 8'd0;
            buffer[0] <= 8'd0; buffer[1] <= 8'd0; buffer[2] <= 8'd0; buffer[3] <= 8'd0;
            buffer[4] <= 8'd0; buffer[5] <= 8'd0; buffer[6] <= 8'd0; buffer[7] <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load input buffer
                        buffer[0] <= arr_0;
                        buffer[1] <= arr_1;
                        buffer[2] <= arr_2;
                        buffer[3] <= arr_3;
                        buffer[4] <= arr_4;
                        buffer[5] <= arr_5;
                        buffer[6] <= arr_6;
                        buffer[7] <= arr_7;
                        idx <= 4'd0;
                        write_idx <= 4'd0;
                        out_len <= 4'd0;
                        // Clear outputs
                        out_0 <= 8'd0; out_1 <= 8'd0; out_2 <= 8'd0; out_3 <= 8'd0;
                        out_4 <= 8'd0; out_5 <= 8'd0; out_6 <= 8'd0; out_7 <= 8'd0;
                    end
                end
                
                PROCESS: begin
                    if (idx < len) begin
                        // Check if even (LSB = 0)
                        if (buffer[idx][0] == 1'b0) begin
                            case (write_idx)
                                4'd0: out_0 <= buffer[idx];
                                4'd1: out_1 <= buffer[idx];
                                4'd2: out_2 <= buffer[idx];
                                4'd3: out_3 <= buffer[idx];
                                4'd4: out_4 <= buffer[idx];
                                4'd5: out_5 <= buffer[idx];
                                4'd6: out_6 <= buffer[idx];
                                4'd7: out_7 <= buffer[idx];
                                default: begin end
                            endcase
                            write_idx <= write_idx + 4'd1;
                        end
                        idx <= idx + 4'd1;
                    end
                end
                
                COMPLETE: begin
                    out_len <= write_idx;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule