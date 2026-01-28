module string_explosion #(
    parameter MAX_STR_LEN = 8,
    parameter MAX_EXP_LEN = 4
)(
    input clk,
    input rst_n,
    input start,
    input [7:0] input_str [0:MAX_STR_LEN-1],
    input [3:0] input_len,
    input [7:0] explosion_str [0:MAX_EXP_LEN-1],
    input [2:0] explosion_len,
    output reg [7:0] result_str [0:MAX_STR_LEN-1],
    output reg [3:0] result_len,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] PROCESS  = 2'd1;
    localparam [1:0] DONE_ST  = 2'd2;
    
    reg [1:0] state;
    reg [3:0] input_index;
    reg [3:0] sp;
    reg [7:0] stack [0:MAX_STR_LEN-1];
    
    integer i, j;
    reg [3:0] temp_sp;
    integer check_offset;
    reg match_flag;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            input_index <= 4'd0;
            sp <= 4'd0;
            done <= 1'b0;
            result_len <= 4'd0;
            for (i = 0; i < MAX_STR_LEN; i = i + 1) begin
                stack[i] <= 8'd0;
                result_str[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        input_index <= 4'd0;
                        sp <= 4'd0;
                    end
                end
                
                PROCESS: begin
                    if (input_index < input_len) begin
                        stack[sp] <= input_str[input_index];
                        temp_sp = sp + 4'd1;
                        
                        if (temp_sp >= {1'b0, explosion_len}) begin
                            match_flag = 1'b1;
                            for (j = 0; j < MAX_EXP_LEN; j = j + 1) begin
                                if (j < explosion_len) begin
                                    check_offset = temp_sp - explosion_len + j;
                                    if (check_offset == sp) begin
                                        if (input_str[input_index] != explosion_str[j]) begin
                                            match_flag = 1'b0;
                                        end
                                    end else begin
                                        if (stack[check_offset] != explosion_str[j]) begin
                                            match_flag = 1'b0;
                                        end
                                    end
                                end
                            end
                            
                            if (match_flag) begin
                                sp <= temp_sp - explosion_len;
                            end else begin
                                sp <= temp_sp;
                            end
                        end else begin
                            sp <= temp_sp;
                        end
                        
                        input_index <= input_index + 4'd1;
                    end else begin
                        state <= DONE_ST;
                    end
                end
                
                DONE_ST: begin
                    result_len <= sp;
                    for (i = 0; i < MAX_STR_LEN; i = i + 1) begin
                        if (i < sp) begin
                            result_str[i] <= stack[i];
                        end else begin
                            result_str[i] <= 8'd0;
                        end
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
endmodule