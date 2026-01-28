module replace_spaces(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_array [0:15],
    input [4:0] len,
    output reg [7:0] result_array [0:15],
    output reg done,
    output reg valid
);

    // Parameters
    localparam [4:0] MAX_LEN = 5'd16;
    localparam [7:0] SPACE_ASCII = 8'd32;
    localparam [7:0] UNDERSCORE_ASCII = 8'd95;
    
    // State machine states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISHED = 2'd2;
    
    // Registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [4:0] index;
    reg [4:0] length_reg;
    reg [7:0] temp_array [0:15];
    integer i;
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && len > 0 && len <= MAX_LEN)
                    next_state = PROCESS;
                else
                    next_state = IDLE;
            end
            PROCESS: begin
                if (index >= length_reg)
                    next_state = FINISHED;
                else
                    next_state = PROCESS;
            end
            FINISHED: begin
                if (!start)
                    next_state = IDLE;
                else
                    next_state = FINISHED;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            index <= 5'd0;
            length_reg <= 5'd0;
            for (i = 0; i < 16; i = i + 1) begin
                result_array[i] <= 8'd0;
                temp_array[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    index <= 5'd0;
                    if (start && len > 0 && len <= MAX_LEN) begin
                        length_reg <= len;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < len)
                                temp_array[i] <= char_array[i];
                            else
                                temp_array[i] <= 8'd0;
                        end
                    end
                end
                
                PROCESS: begin
                    if (index < length_reg) begin
                        if (temp_array[index] == SPACE_ASCII) begin
                            temp_array[index] <= UNDERSCORE_ASCII;
                        end else if (temp_array[index] == UNDERSCORE_ASCII) begin
                            temp_array[index] <= SPACE_ASCII;
                        end
                        index <= index + 1;
                    end
                end
                
                FINISHED: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    for (i = 0; i < 16; i = i + 1) begin
                        result_array[i] <= temp_array[i];
                    end
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
        end
    end

endmodule