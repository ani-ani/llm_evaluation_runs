module dna_editing (
    input clk,
    input rst_n,
    input start,
    input [0:0] op1_type [0:1999],
    input [31:0] op1_pos [0:1999],
    input [7:0] op1_char [0:1999],
    input [0:0] op2_type [0:1999],
    input [31:0] op2_pos [0:1999],
    input [7:0] op2_char [0:1999],
    output reg result
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INIT = 2'd1;
    localparam [1:0] EXEC_OPS = 2'd2;
    localparam [1:0] COMPARE = 2'd3;
    localparam [1:0] DONE = 2'd4;
    
    reg [1:0] state, next_state;
    reg [7:0] string1 [0:999];
    reg [7:0] string2 [0:999];
    
    integer i;
    reg [31:0] pos_idx;
    reg [31:0] op_idx;
    reg [31:0] str_idx;
    reg [31:0] compare_idx;
    reg [31:0] temp_pos;
    reg temp_result;
    
    reg [7:0] k;
    reg [31:0] j;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            for (i = 0; i < 1000; i = i + 1) begin
                string1[i] <= 8'd0;
                string2[i] <= 8'd0;
            end
            op_idx <= 32'd0;
            str_idx <= 32'd0;
            compare_idx <= 32'd0;
            temp_result <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    result <= 1'b0;
                    op_idx <= 32'd0;
                    str_idx <= 32'd0;
                    compare_idx <= 32'd0;
                    temp_result <= 1'b0;
                end
                
                INIT: begin
                    for (i = 0; i < 1000; i = i + 1) begin
                        string1[i] <= 8'd0;
                        string2[i] <= 8'd0;
                    end
                    op_idx <= 32'd0;
                end
                
                EXEC_OPS: begin
                    if (op_idx < 32'd2000) begin
                        if (op_idx < 32'd2000 && op1_type[op_idx] == 1'b1) begin
                            temp_pos <= op1_pos[op_idx] % 32'd1000;
                            if (op1_pos[op_idx] % 32'd1000 < 32'd1000) begin
                                if (op1_pos[op_idx] % 32'd1000 < 32'd999) begin
                                    for (j = 0; j < 999; j = j + 1) begin
                                        if (j >= temp_pos && j < 999) begin
                                            string1[j+1] <= string1[j];
                                        end
                                    end
                                end
                                string1[temp_pos] <= op1_char[op_idx];
                            end
                        end else if (op_idx < 32'd2000 && op1_type[op_idx] == 1'b0) begin
                            temp_pos <= op1_pos[op_idx] % 32'd1000;
                            if (op1_pos[op_idx] % 32'd1000 < 32'd1000) begin
                                for (j = 0; j < 999; j = j + 1) begin
                                    if (j >= temp_pos && j < 999) begin
                                        string1[j] <= string1[j+1];
                                    end
                                end
                                string1[999] <= 8'd0;
                            end
                        end
                        
                        if (op_idx < 32'd2000 && op2_type[op_idx] == 1'b1) begin
                            temp_pos <= op2_pos[op_idx] % 32'd1000;
                            if (op2_pos[op_idx] % 32'd1000 < 32'd1000) begin
                                if (op2_pos[op_idx] % 32'd1000 < 32'd999) begin
                                    for (j = 0; j < 999; j = j + 1) begin
                                        if (j >= temp_pos && j < 999) begin
                                            string2[j+1] <= string2[j];
                                        end
                                    end
                                end
                                string2[temp_pos] <= op2_char[op_idx];
                            end
                        end else if (op_idx < 32'd2000 && op2_type[op_idx] == 1'b0) begin
                            temp_pos <= op2_pos[op_idx] % 32'd1000;
                            if (op2_pos[op_idx] % 32'd1000 < 32'd1000) begin
                                for (j = 0; j < 999; j = j + 1) begin
                                    if (j >= temp_pos && j < 999) begin
                                        string2[j] <= string2[j+1];
                                    end
                                end
                                string2[999] <= 8'd0;
                            end
                        end
                        op_idx <= op_idx + 32'd1;
                    end
                end
                
                COMPARE: begin
                    if (compare_idx < 32'd1000) begin
                        if (string1[compare_idx] != string2[compare_idx]) begin
                            temp_result <= 1'b1;
                        end
                        compare_idx <= compare_idx + 32'd1;
                    end
                end
                
                DONE: begin
                    result <= temp_result;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                end
            endcase
        end
    end
    
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
                else next_state = IDLE;
            end
            INIT: next_state = EXEC_OPS;
            EXEC_OPS: begin
                if (op_idx >= 32'd2000) next_state = COMPARE;
                else next_state = EXEC_OPS;
            end
            COMPARE: begin
                if (compare_idx >= 32'd1000) next_state = DONE;
                else next_state = COMPARE;
            end
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule